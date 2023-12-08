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

// client is a simple client that demonstrates fetching data from a distributor.
package main

import (
	"flag"
	"fmt"
	"net/http"

	"github.com/golang/glog"
	"github.com/transparency-dev/distributor/client"
	"github.com/transparency-dev/distributor/config"
	f_log "github.com/transparency-dev/formats/log"
	"golang.org/x/exp/maps"
	"golang.org/x/mod/sumdb/note"
)

var (
	baseURL = flag.String("base_url", "https://api.transparency.dev", "The base URL of the distributor")
	n       = flag.Uint("n", 2, "The desired number of witness signatures for each log")
)

func main() {
	flag.Parse()

	ls := getLogsOrDie()
	ws := getWitnessesOrDie()

	d := client.NewRestDistributor(*baseURL, http.DefaultClient)

	logs, err := d.GetLogs()
	if err != nil {
		glog.Exitf("Failed to enumerate logs: %v", err)
	}
	for _, l := range logs {
		log, ok := ls[string(l)]
		if !ok {
			glog.Warningf("Saw unknown logID %q from distributor", l)
			continue
		}
		cp, err := d.GetCheckpointN(l, *n)
		if err != nil {
			glog.Warningf("Could not get checkpoint.%d for log %q (%s): %v", *n, log.Origin, l, err)
			continue
		}
		if _, _, _, err := f_log.ParseCheckpoint(cp, log.Origin, log.Verifier, maps.Values(ws)...); err != nil {
			glog.Warningf("Failed to open checkpoint: %v", err)
			continue
		}
		fmt.Printf("Checkpoint.%d for log %s:\n\n%s\n\n", *n, l, cp)
	}
}

func getLogsOrDie() map[string]config.LogInfo {
	r, err := config.DefaultLogs()
	if err != nil {
		glog.Exitf("Failed to get log config: %v", err)
	}
	return r
}

func getWitnessesOrDie() map[uint32]note.Verifier {
	r, err := config.DefaultWitnesses()
	if err != nil {
		glog.Exitf("Failed to get witness config: %v", err)
	}
	return r
}
