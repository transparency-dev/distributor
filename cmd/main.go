// Copyright 2023 Google LLC. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// distributor is a server designed to make witnessed checkpoints of
// verifiable logs available to clients in an efficient manner.
package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"

	"cloud.google.com/go/cloudsqlconn"
	"github.com/golang/glog"
	"github.com/gorilla/mux"
	"github.com/transparency-dev/distributor/cmd/internal/distributor"
	ihttp "github.com/transparency-dev/distributor/cmd/internal/http"
	"github.com/transparency-dev/distributor/config"
	"golang.org/x/mod/sumdb/note"
	"golang.org/x/sync/errgroup"

	_ "embed"

	"github.com/go-sql-driver/mysql"
	_ "github.com/go-sql-driver/mysql"
)

var (
	addr        = flag.String("listen", ":8080", "Address to listen on")
	useCloudSql = flag.Bool("use_cloud_sql", false, "Set to true to set up the DB connection using cloudsql connection. This will ignore mysql_uri and generate it from env variables.")
	mysqlURI    = flag.String("mysql_uri", "", "URI for MySQL DB")

	witnessConfigFile = flag.String("witness_config_file", "", "Path to a file containing the public keys of allowed witnesses")
)

func main() {
	flag.Parse()
	ctx := context.Background()

	httpListener, err := net.Listen("tcp", *addr)
	if err != nil {
		glog.Exitf("Failed to listen on %q", *addr)
	}

	ws := getWitnessesOrDie()
	ls := getLogsOrDie()
	db := getDatabaseOrDie()

	d, err := distributor.NewDistributor(ws, ls, db)
	if err != nil {
		glog.Exitf("Failed to create distributor: %v", err)
	}
	r := mux.NewRouter()
	s := ihttp.NewServer(d)
	s.RegisterHandlers(r)
	srv := http.Server{
		Handler: r,
	}

	// This error group will be used to run all top level processes.
	// If any process dies, then all of them will be stopped via context cancellation.
	g, ctx := errgroup.WithContext(ctx)
	g.Go(func() error {
		glog.Info("HTTP server goroutine started")
		defer glog.Info("HTTP server goroutine done")
		return srv.Serve(httpListener)
	})
	g.Go(func() error {
		// This goroutine brings down the HTTP server when ctx is done.
		glog.Info("HTTP server-shutdown goroutine started")
		defer glog.Info("HTTP server-shutdown goroutine done")
		<-ctx.Done()
		return srv.Shutdown(ctx)
	})
	if err := g.Wait(); err != nil {
		glog.Errorf("failed with error: %v", err)
	}
}

func getDatabaseOrDie() *sql.DB {
	if *useCloudSql {
		return getCloudSqlOrDie()
	}
	if len(*mysqlURI) == 0 {
		glog.Exitf("mysql_uri is required")
	}
	glog.Infof("Connecting to DB at %q", *mysqlURI)
	db, err := sql.Open("mysql", *mysqlURI)
	if err != nil {
		glog.Exitf("Failed to connect to DB: %v", err)
	}
	return db
}

func getCloudSqlOrDie() *sql.DB {
	mustGetenv := func(k string) string {
		v := os.Getenv(k)
		if v == "" {
			glog.Exitf("Failed precondition: %s environment variable not set.", k)
		}
		return v
	}
	var (
		dbUser                 = mustGetenv("DB_USER")                  // e.g. 'my-db-user'
		dbPwd                  = mustGetenv("DB_PASS")                  // e.g. 'my-db-password'
		dbName                 = mustGetenv("DB_NAME")                  // e.g. 'my-database'
		instanceConnectionName = mustGetenv("INSTANCE_CONNECTION_NAME") // e.g. 'project:region:instance'
	)

	d, err := cloudsqlconn.NewDialer(context.Background())
	if err != nil {
		glog.Exitf("cloudsqlconn.NewDialer: %w", err)
	}
	var opts []cloudsqlconn.DialOption
	mysql.RegisterDialContext("cloudsqlconn",
		func(ctx context.Context, addr string) (net.Conn, error) {
			return d.Dial(ctx, instanceConnectionName, opts...)
		})

	dbURI := fmt.Sprintf("%s:%s@cloudsqlconn(localhost:3306)/%s", dbUser, dbPwd, dbName)

	dbPool, err := sql.Open("mysql", dbURI)
	if err != nil {
		glog.Exitf("sql.Open: %w", err)
	}
	return dbPool
}

func getLogsOrDie() map[string]config.LogInfo {
	r, err := config.DefaultLogs()
	if err != nil {
		glog.Exitf("Failed to unmarshal log config: %v", err)
	}
	for id, l := range r {
		glog.Infof("Added log %q (%s)", l.Origin, id)
	}
	return r
}

func getWitnessesOrDie() map[string]note.Verifier {
	cfg := config.WitnessesYAML
	if *witnessConfigFile != "" {
		c, err := os.ReadFile(*witnessConfigFile)
		if err != nil {
			glog.Exitf("Failed to read witness_config_file (%q): %v", *witnessConfigFile, err)
		}
		glog.Infof("Witness list read from %v", *witnessConfigFile)
		cfg = c
	} else {
		glog.Info("Flag witness_config_file not specified; default witness list will be used")
	}
	w, err := config.ParseWitnessesConfig(cfg)
	if err != nil {
		glog.Exitf("Failed to unmarshal witness config: %v", err)
	}

	r := make(map[string]note.Verifier, len(w))
	for _, v := range w {
		r[v.Name()] = v
	}
	return r
}
