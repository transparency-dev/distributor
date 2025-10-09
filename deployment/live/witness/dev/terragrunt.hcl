include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

inputs = merge(
  include.root.locals,
  {
    witness_docker_image = "us-central1-docker.pkg.dev/checkpoint-distributor/distributor-docker-dev/witness:latest"
    public_witness_config_urls = ["https://raw.githubusercontent.com/transparency-dev/witness-network/refs/heads/main/site/static/testing/log-list.1"]
    ephemeral = true
  }
)

