# Distributor

[![Go Reference](https://pkg.go.dev/badge/github.com/transparency-dev/distributor.svg)](https://pkg.go.dev/github.com/transparency-dev/distributor)
[![Go Report Card](https://goreportcard.com/badge/github.com/transparency-dev/distributor)](https://goreportcard.com/report/github.com/transparency-dev/distributor)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/transparency-dev/distributor/badge)](https://securityscorecards.dev/viewer/?uri=github.com/transparency-dev/distributor)
[![Slack Status](https://img.shields.io/badge/Slack-Chat-blue.svg)](https://transparency-dev.slack.com/)

## Overview

The distributor is a RESTful service that makes witnessed checkpoints available.

This code is designed such that anyone can easily run it, see [instruction below](#running-in-docker).

There is a public good instance of the distributor running that makes available checkpoints witnessed by the [Armored Witness](https://github.com/transparency-dev/armored-witness/) production fleet.
Below is the output of querying this distributor for all witnessed checkpoints using a client provided in this repository:

```shell
go run github.com/transparency-dev/distributor/cmd/client@main

Fetching checkpoints from distributor...
╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾
Log "transparency.dev-aw-ftlog-ci-3" (0b963db2162e516836b4afbf8ff75aca120af717d3b93a332464cd5af4146e99)
✅ Got checkpoint:

transparency.dev/armored-witness/firmware_transparency/ci/3
59
kOFMkeamIdrYFLx5zbWFhflak6dlEEDOU++fxYEZMBw=

— transparency.dev-aw-ftlog-ci-3 P2iVIt3Jsaha3E2i0MHdKZ6fgYJTgXO86nUsxKPVq6uTwRSclTSh/ELnDGbNL+XDyD3EkWIdL2AGGNmbN7IN2rB/7gE=
— ArmoredWitness-weathered-rain CnjfIAAAAABnGRrHjQi7IZQqVea4YnU/ADsv844r1ezGjvubUy1MMJm4as9bRiT70xNWQ67RCA76LMy7SdX4qJNIzL3eSS1BGFWqCw==
— ArmoredWitness-floral-sky x88LbQAAAABnGRrDEq4Tfy7IIVPqkdXbcufUkCzRRbE3fABZ/jvtg5aFHVMuMR8cV6dVqECDBiH1zRxhNaCQOXSwNLSeJs+NzWt1BA==

Witness timestamps:
— ArmoredWitness-weathered-rain: 4 months ago (2024-10-23T16:48:23+01:00)
— ArmoredWitness-floral-sky: 4 months ago (2024-10-23T16:48:19+01:00)

╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾╾
Log "pixel_transparency_log" (2371c7aa76ca0d588c7f21317b789071bb63593bd2c3d7b02ca5842f03680fda)
✅ Got checkpoint:

developers.google.com/android/binary_transparency/0
611
2GZ1zmS5VkfUZmn2ZyR4KZXwHLD+xnwBIWzql/cD50w=

— pixel_transparency_log csh42zBFAiAd3Y1FwqNTt5RglY0uG7heC6Yu1gEbXXPYmZ7LdOILMAIhAIt68PnR/3TADAaC7hvrSHbpziV7TmpIwOUydLmcjyTQ
— ArmoredWitness-small-breeze nRq5UQAAAABnoqrsRIofXn68vTohcAm2KG4ACGyRPNePUk02BSWD0WKV5ElejTk5Z+Tm3GmJ5j/etA+fkL9XuaQsnTyZbr437sF4AQ==
— ArmoredWitness-autumn-wood qZb5XQAAAABnoqrl57G9CblEl3lwwuqzbaJvVMqNiZCbYZseYT1YZHYmls3CmT1wxZ1fNgM4RxHuUxjAwcI2ghTx6R5aCg+L0DGPBA==

Witness timestamps:
— ArmoredWitness-small-breeze: 3 weeks ago (2025-02-05T00:03:56Z)
— ArmoredWitness-autumn-wood: 3 weeks ago (2025-02-05T00:03:49Z)
...
```

For custom querying or integration with the distributor, see the [API](./api/http.go) for the endpoints supported.

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
- Slack: https://transparency-dev.slack.com/ ([invitation](https://join.slack.com/t/transparency-dev/shared_invite/zt-2jt6643n4-I5wLUo90_tvTVd4nfmfDug))
