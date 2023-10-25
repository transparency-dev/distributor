# Distributor GCP Deployment

This terraform script configures a GCP project with a running distributor.

First authenticate via `gcloud` as a principle with sufficient ACLs for
the project:
```bash
gcloud auth application-default login
```

Terraforming the project can be done with:
```bash
# Check that the project and region are right and edit if not!
cat terraform.tfvars

terraform init
terraform apply
```

This should bring up the DB and Distributor running in Cloud Run.

After doing that, it's possible to query the distributor using curl:

```bash
curl -i -H \
"Authorization: Bearer $(gcloud auth print-identity-token)" \
$DISTRIBUTOR_URI/distributor/v0/logs
```

Note that you'll need to substitute the URI for the new instance that is
created on apply. This is output from `terraform apply` under the name
`distributor_uri` but you can find this in the Cloud Run area of GCP if
you lose it down the back of the sofa.

- [ ] TODO(mhutchinson): Set up public URL mapping
- [ ] TODO(mhutchinson): make the state be stored in a GCS bucket instead of
      output into a local file.

## Connecting to the DB

Connecting to the DB from a local machine is possible via [Cloud SQL Proxy](https://cloud.google.com/sql/docs/mysql/connect-auth-proxy).
