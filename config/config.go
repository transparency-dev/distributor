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

// Package config has top-level configs etc. for the distributor implementation
// and associated commands.
package config

import (
	_ "embed"
	"fmt"

	"github.com/transparency-dev/formats/log"
	f_note "github.com/transparency-dev/formats/note"
	"golang.org/x/mod/sumdb/note"
	"gopkg.in/yaml.v3"
)

var (
	//go:embed logs.yaml
	LogsYAML []byte
)

// DefaultLogs returns a parsed representation of the embedded LogsYAML config.
// The returned map is keyed by LogID.
func DefaultLogs() (map[string]LogInfo, error) {
	return ParseLogConfig(LogsYAML)
}

// LogInfo contains the information that the distributor needs to know about
// a log, other than its ID.
type LogInfo struct {
	Origin   string
	Verifier note.Verifier
}

// ParseLogConfig parses the passed in log config, and returns a map keyed by LogID.
func ParseLogConfig(y []byte) (map[string]LogInfo, error) {
	logsCfg := struct {
		Logs []struct {
			Origin    string `yaml:"Origin"`
			PublicKey string `yaml:"PublicKey"`
		} `yaml:"Logs"`
	}{}

	if err := yaml.Unmarshal(y, &logsCfg); err != nil {
		return nil, fmt.Errorf("failed to unmarshal log config: %v", err)
	}
	ls := make(map[string]LogInfo)
	for _, l := range logsCfg.Logs {
		lSigV, err := f_note.NewVerifier(l.PublicKey)
		if err != nil {
			return nil, fmt.Errorf("invalid log public key: %v", err)
		}
		ls[log.ID(l.Origin)] = LogInfo{
			Origin:   l.Origin,
			Verifier: lSigV,
		}
	}
	return ls, nil
}

// ParseWitnessesConfig parses the passed in witnesses config, and returns a map keyed
// by the raw verifier key string.
func ParseWitnessesConfig(y []byte) (map[string]note.Verifier, error) {
	witCfg := struct {
		Witnesses []string `yaml:"Witnesses"`
	}{}
	if err := yaml.Unmarshal(y, &witCfg); err != nil {
		return nil, fmt.Errorf("failed to unmarshal witness config: %v", err)
	}
	ws := make(map[string]note.Verifier)
	for _, w := range witCfg.Witnesses {
		// TODO(mhutchinson): Upgrade this to f_note.NewVerifierForCosignatureV1
		wSigV, err := note.NewVerifier(w)
		if err != nil {
			return nil, fmt.Errorf("invalid witness public key: %v", err)
		}
		ws[w] = wSigV
	}
	return ws, nil
}
