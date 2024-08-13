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
	"strings"
	"time"

	"github.com/dustin/go-humanize"
	"github.com/golang/glog"
	"github.com/transparency-dev/distributor/client"
	"github.com/transparency-dev/distributor/config"
	f_log "github.com/transparency-dev/formats/log"
	f_note "github.com/transparency-dev/formats/note"
	"golang.org/x/exp/maps"
	"golang.org/x/mod/sumdb/note"
)

var (
	baseURL = flag.String("base_url", "https://api.transparency.dev", "The base URL of the distributor")
	n       = flag.Uint("n", 2, "The desired number of witness signatures for each log")
	witness = flag.String("w", "", "Show the latest checkpoints for this witness short name")
)

func main() {
	flag.Parse()

	d := client.NewRestDistributor(*baseURL, http.DefaultClient)

	ls := getLogsOrDie()
	ws := getWitnessesOrDie(d)

	logs, err := d.GetLogs()
	if err != nil {
		glog.Exitf("❌ Failed to enumerate logs: %v", err)
	}
	fmt.Println("Fetching checkpoints from distributor...")
	for _, l := range logs {
		fmt.Println(strings.Repeat("╾", 70))
		log, ok := ls[string(l)]
		if !ok {
			fmt.Printf("️❌ Saw unknown logID %q from distributor\n", l)
			continue
		}
		fmt.Printf("Log %q (%s)\n", log.Verifier.Name(), l)
		var cp []byte
		var err error
		if *witness == "" {
			cp, err = d.GetCheckpointN(l, *n)
			if err != nil {
				fmt.Printf("❌️ Could not get checkpoint.%d: %v\n", *n, err)
				continue
			}
		} else {
			cp, err = d.GetCheckpointWitness(l, *witness)
			if err != nil {
				fmt.Printf("❌️ Could not get checkpoint: %v\n", err)
				continue
			}
		}
		_, _, cpN, err := f_log.ParseCheckpoint(cp, log.Origin, log.Verifier, maps.Values(ws)...)
		if err != nil {
			fmt.Printf("❌️ Failed to open checkpoint: %v\n", err)
			continue
		}

		times := []string{}
		for _, sig := range cpN.Sigs {
			if _, ok := ws[sig.Hash]; ok {
				t, err := f_note.CoSigV1Timestamp(sig)
				if err != nil {
					continue
				}
				times = append(times, fmt.Sprintf("— %s: %s (%s)", sig.Name, humanize.Time(t), t.Format(time.RFC3339)))
			}
		}
		fmt.Printf("✅ Got checkpoint:\n\n%s\nWitness timestamps:\n%s\n\n", string(cp), strings.Join(times, "\n"))
	}
}

func getLogsOrDie() map[string]config.LogInfo {
	r, err := config.DefaultLogs()
	if err != nil {
		glog.Exitf("Failed to get log config: %v", err)
	}
	return r
}

func getWitnessesOrDie(c *client.RestDistributor) map[uint32]note.Verifier {
	rawWs, err := c.GetWitnesses()
	if err != nil {
		glog.Exitf("Failed to GetWitnesses() from distributor: %v", err)
	}

	ws := make(map[uint32]note.Verifier)
	for _, w := range rawWs {
		wSigV, err := f_note.NewVerifierForCosignatureV1(w)
		if err != nil {
			glog.Exitf("Invalid witness public key retrieved from distributor: %v: %v", w, err)
		}
		ws[wSigV.KeyHash()] = wSigV
	}
	return ws
}
