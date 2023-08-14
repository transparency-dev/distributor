# Distributor

[![Go Reference](https://pkg.go.dev/badge/github.com/transparency-dev/distributor.svg)](https://pkg.go.dev/github.com/transparency-dev/distributor)
[![Go Report Card](https://goreportcard.com/badge/github.com/transparency-dev/distributor)](https://goreportcard.com/report/github.com/transparency-dev/distributor)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/transparency-dev/distributor/badge)](https://securityscorecards.dev/viewer/?uri=github.com/transparency-dev/distributor)
[![Slack Status](https://img.shields.io/badge/Slack-Chat-blue.svg)](https://gtrillian.slack.com/)

## Overview

The distributor is a RESTful service that makes witnessed checkpoints available.

## Running in Docker

The distributor can be started using `docker compose`.
The following command will bring up the distributor on port `8080`:
```bash
docker compose up -d
```

If using a Raspberry Pi, the above command will fail because no suitable MariaDB image can be
installed. Instead, use this command to install an image that works:
```bash
docker compose -f docker-compose.yaml -f docker-compose.rpi.yaml up -d
```

## Support
* Mailing list: https://groups.google.com/forum/#!forum/trillian-transparency
* Slack: https://gtrillian.slack.com/ (invitation)
