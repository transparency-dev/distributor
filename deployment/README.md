# Distributor GCP Deployment

This directory contains configuration-as-code to deploy the distributor to GCP.
 - `modules`: a terraform module to deploy the distributor
 - `live`: terragrunt configurations for deploying to different environments

Deploying this requires installation of:
 - `terraform`
 - [`terragrunt`](https://terragrunt.gruntwork.io/docs/getting-started/install/)

## Deploying

First authenticate via `gcloud` as a principle with sufficient ACLs for
the project:
```bash
gcloud auth application-default login
```

Terraforming the project can be done by:
 1. `cd` to the relevant `live` directory for the environment to change
 2. Run `terragrunt apply`

This should bring up the DB and Distributor running in Cloud Run.

After doing that, it's possible to query the distributor using curl:

```bash
curl -i -H \
"Authorization: Bearer $(gcloud auth print-identity-token)" \
$DISTRIBUTOR_URI/distributor/v0/logs
```

Note that you'll need to substitute the URI for the new instance that is
created on apply. This is output from `terragrunt apply` under the name
`distributor_uri` but you can find this in the Cloud Run area of GCP if
you lose it down the back of the sofa.

## Terraform State

The state of the environments are stored in GCS buckets, which means that
multiple collaborators can work together on the project without passing around
terraform state files or risking stomping on each other's changes.

## Connecting to the DB

Connecting to the DB from a local machine is possible via [Cloud SQL Proxy](https://cloud.google.com/sql/docs/mysql/connect-auth-proxy).
