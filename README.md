# Distributor

[![Go Reference](https://pkg.go.dev/badge/github.com/transparency-dev/distributor.svg)](https://pkg.go.dev/github.com/transparency-dev/distributor)
[![Go Report Card](https://goreportcard.com/badge/github.com/transparency-dev/distributor)](https://goreportcard.com/report/github.com/transparency-dev/distributor)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/transparency-dev/distributor/badge)](https://securityscorecards.dev/viewer/?uri=github.com/transparency-dev/distributor)
[![Slack Status](https://img.shields.io/badge/Slack-Chat-blue.svg)](https://transparency-dev.slack.com/)

## Overview

The distributor is a RESTful service that makes witnessed checkpoints available.

## Running in Docker

The distributor can be started using `docker compose`.
The following command will bring up the distributor on port `8080`:
```bash
docker compose up -d
```

Note that this will only accept witnessed checkpoints from witnesses in the
`config/witnesses-dev.yaml` directory.
To change the permitted witnesses, modify the `docker-compose.yaml` file to
include a different file, or configure the distributor binary with the witnesses
specified directly via the `witKey` flag.

## Support
* Mailing list: https://groups.google.com/forum/#!forum/trillian-transparency
- Slack: https://transparency-dev.slack.com/ ([invitation](https://join.slack.com/t/transparency-dev/shared_invite/zt-27pkqo21d-okUFhur7YZ0rFoJVIOPznQ))
