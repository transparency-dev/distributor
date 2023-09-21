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
	i_note "github.com/transparency-dev/distributor/internal/note"
	"github.com/transparency-dev/formats/log"
	"golang.org/x/mod/sumdb/note"
	"golang.org/x/sync/errgroup"
	"gopkg.in/yaml.v3"

	_ "embed"

	"github.com/go-sql-driver/mysql"
	_ "github.com/go-sql-driver/mysql"
)

var (
	addr        = flag.String("listen", ":8080", "Address to listen on")
	useCloudSql = flag.Bool("use_cloud_sql", false, "Set to true to set up the DB connection using cloudsql connection. This will ignore mysql_uri and generate it from env variables.")
	mysqlURI    = flag.String("mysql_uri", "", "URI for MySQL DB")

	witnessConfigFile = flag.String("witness_config_file", "", "Path to a file containing the public keys of allowed witnesses")

	// configLogs is the config for the logs this distributor will accept.
	//go:embed logs.yaml
	configLogs []byte

	// defaultWitnesses is the witness config that will be used if witness_config_file flag is not provided.
	//go:embed witnesses.yaml
	defaultWitnesses []byte
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

func getLogsOrDie() map[string]distributor.LogInfo {
	logsCfg := logsConfig{}
	if err := yaml.Unmarshal(configLogs, &logsCfg); err != nil {
		glog.Exitf("Failed to unmarshal log config: %v", err)
	}
	ls := make(map[string]distributor.LogInfo, len(logsCfg.Logs))
	for _, l := range logsCfg.Logs {
		lSigV, err := i_note.NewVerifier(l.PublicKeyType, l.PublicKey)
		if err != nil {
			glog.Exitf("Invalid log public key: %v", err)
		}
		l.ID = log.ID(l.Origin)
		ls[l.ID] = distributor.LogInfo{
			Origin:   l.Origin,
			Verifier: lSigV,
		}
		glog.Infof("Added log %q (%s)", l.Origin, l.ID)
	}
	return ls
}

func getWitnessesOrDie() map[string]note.Verifier {
	var configWitnesses []byte
	if len(*witnessConfigFile) == 0 {
		glog.Info("Flag witness_config_file not specified; default witness list will be used")
		configWitnesses = defaultWitnesses
	} else {
		var err error
		configWitnesses, err = os.ReadFile(*witnessConfigFile)
		if err != nil {
			glog.Exitf("Failed to read witness_config_file (%q): %v", *witnessConfigFile, err)
		}
		glog.Info("Witness list read from %v", *witnessConfigFile)
	}

	witCfg := witnessConfig{}
	if err := yaml.Unmarshal(configWitnesses, &witCfg); err != nil {
		glog.Exitf("Failed to unmarshal witness config: %v", err)
	}
	ws := make(map[string]note.Verifier, len(witCfg.Witnesses))
	for _, w := range witCfg.Witnesses {
		wSigV, err := note.NewVerifier(w)
		if err != nil {
			glog.Exitf("Invalid witness public key: %v", err)
		}
		ws[wSigV.Name()] = wSigV
	}

	return ws
}

// logsConfig contains all of the metadata for the logs.
type logsConfig struct {
	// Log defines the log checkpoints are being distributed for.
	Logs []logConfig `yaml:"Logs"`
}

// Log describes a verifiable log in a config file.
type logConfig struct {
	// ID is used to refer to the log in directory paths.
	// This field should not be manually set in configs, instead it will be
	// derived automatically by logfmt.ID.
	ID string `yaml:"ID"`
	// PublicKey used to verify checkpoints from this log.
	PublicKey string `yaml:"PublicKey"`
	// PublicKeyType identifies the format of the key present in the PublicKey field.
	// If unset, the key should be assumed to be in a format which `note.NewVerifier`
	// understands.
	PublicKeyType string `yaml:"PublicKeyType"`
	// Origin is the expected first line of checkpoints from the log.
	Origin string `yaml:"Origin"`
	// URL is the URL of the root of the log.
	// This is optional if direct log communication is not required.
	URL string `yaml:"URL"`
}

// witnessConfig contains all of the witness public keys.
type witnessConfig struct {
	// Witnesses lists the public keys that will be accepted as witnesses.
	Witnesses []string `yaml:"Witnesses"`
}
