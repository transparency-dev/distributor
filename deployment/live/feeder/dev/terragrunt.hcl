include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

inputs = merge(
  include.root.locals,
  {
    feeder_docker_image = "us-central1-docker.pkg.dev/checkpoint-distributor/distributor-docker-dev/feeder:latest"
    extra_args = [
      "--witness_url=https://api.transparency.dev/dev/witness/little-garden",
    ]
    ephemeral = true
  }
)

