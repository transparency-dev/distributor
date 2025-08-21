include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

inputs = merge(
  include.root.locals,
  {
    witness_docker_image = "us-central1-docker.pkg.dev/checkpoint-distributor/distributor-docker-dev/witness:latest"
    ephemeral = true
  }
)

