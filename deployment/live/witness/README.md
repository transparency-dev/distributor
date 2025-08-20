# Witness deployment

The directories under here contain the top-level terragrunt files for the deployment environments.

In all cases, before deploying for the first time, you MUST have created the witness public and
private keys or the `terragrunt apply` will fail.

The keys can be generated and stored in Secret Manager from a shell on machine with appropriate
gcloud auth, e.g. CloudShell.
The example command below will generate a public and private note key-pair, using the provided
witness name, and will use those to create and populate the initial version of two Secret Manager
secrets called `witness_public_XXX` and `witness_secret_XXX` respectively, where XXX is the name
of the target deployment environment.

```bash
$ export TARGET="dev" # This MUST match the name of the directory you're deploying
$ export WITNESS_NAME="..." # This is the witness name we're generating keys for. It should follow the schemaless-url recommendation from `tlog-witness`.
$ go run github.com/transparency-dev/serverless-log/cmd/generate_keys@HEAD \
    --key_name="${WITNESS_NAME}" \
    --print | 
    tee >(grep -v PRIVATE | gcloud secrets create witness_public_${TARGET} --data-file=-) | 
    grep PRIVATE | 
    gcloud secrets create witness_secret_${TARGET} --data-file=- 
Created version [1] of the secret [witness_public_dev].
Created version [1] of the secret [witness_secret_dev].
```
