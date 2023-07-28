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
	"net"
	"net/http"
	"os"

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

	_ "github.com/go-sql-driver/mysql"
)

var (
	addr     = flag.String("listen", ":8080", "Address to listen on")
	mysqlURI = flag.String("mysql_uri", "", "URI for MySQL DB")

	witnessConfigFile = flag.String("witness_config_file", "", "Path to a file containing the public keys of allowed witnesses")

	// configLogs is the config for the logs this distributor will accept.
	//go:embed logs.yaml
	configLogs []byte
)

func main() {
	flag.Parse()
	ctx := context.Background()

	configWitnesses, err := os.ReadFile(*witnessConfigFile)
	if err != nil {
		glog.Exitf("Failed to read witness_config_file (%q): %v", *witnessConfigFile, err)
	}
	// This error group will be used to run all top level processes.
	// If any process dies, then all of them will be stopped via context cancellation.
	g, ctx := errgroup.WithContext(ctx)
	httpListener, err := net.Listen("tcp", *addr)
	if err != nil {
		glog.Exitf("Failed to listen on %q", *addr)
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
	if len(*mysqlURI) == 0 {
		glog.Exitf("mysql_uri is required")
	}
	glog.Infof("Connecting to DB at %q", *mysqlURI)
	db, err := sql.Open("mysql", *mysqlURI)
	if err != nil {
		glog.Exitf("Failed to connect to DB: %v", err)
	}

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
