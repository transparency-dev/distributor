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

// Package client contains a simple RESTful client that retrieves information from
// a distributor at a known URL.
package client

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"

	"github.com/transparency-dev/distributor/api"
)

// LogID is the globally unique name for a log.
type LogID string

// NewRestDistributor constructs a new client.
func NewRestDistributor(baseURL string, client *http.Client) *RestDistributor {
	return &RestDistributor{
		baseURL: baseURL,
		client:  client,
	}
}

// RestDistributor is a client that fetches data via RESTful HTTP calls.
type RestDistributor struct {
	baseURL string
	client  *http.Client
}

// GetLogs returns all logs that the distributor knows about.
func (d *RestDistributor) GetLogs() ([]LogID, error) {
	u, err := url.Parse(d.baseURL + api.HTTPGetLogs)
	if err != nil {
		return nil, err
	}
	r := make([]LogID, 0)
	bs, err := d.fetchData(u)
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(bs, &r); err != nil {
		return nil, err
	}
	return r, nil
}

// GetCheckpointN returns the freshest checkpoint for the log that at least N witnesses
// have provided signatures for.
func (d *RestDistributor) GetCheckpointN(l LogID, n uint) ([]byte, error) {
	u, err := url.Parse(d.baseURL + fmt.Sprintf(api.HTTPGetCheckpointN, l, strconv.Itoa(int(n))))
	if err != nil {
		return nil, err
	}
	return d.fetchData(u)
}

// GetCheckpointWitness returns the latest checkpoint that a named witness has provided
// for the given log.
func (d *RestDistributor) GetCheckpointWitness(l LogID, w string) ([]byte, error) {
	u, err := url.Parse(d.baseURL + fmt.Sprintf(api.HTTPCheckpointByWitness, l, w))
	if err != nil {
		return nil, err
	}
	return d.fetchData(u)
}

func (d *RestDistributor) fetchData(u *url.URL) ([]byte, error) {
	resp, err := d.client.Get(u.String())
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read body: %v", err)
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("bad status response (%s): %q", resp.Status, body)
	}
	return body, nil
}
