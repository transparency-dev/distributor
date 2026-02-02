include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

inputs = merge(
  include.root.locals,
  {
    public_witness_config_urls = ["https://raw.githubusercontent.com/transparency-dev/witness-network/refs/heads/main/lists/testing/log-list.1"]
    witness_docker_image       = "us-central1-docker.pkg.dev/checkpoint-distributor/distributor-docker-dev/witness:latest"
    witness_secret_name        = "witness_secret_dev"
    witness_service_account    = "cloudrun-witness-dev-sa@checkpoint-distributor.iam.gserviceaccount.com"

    ephemeral = true
  }
)

