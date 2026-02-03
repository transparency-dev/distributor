include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  dev_witness_urls = [
    "https://api.transparency.dev/dev/witness/little-garden",
  ]

  all_witness_urls = local.dev_witness_urls
}

inputs = merge(
  include.root.locals,
  {
    feeder_docker_image = "us-central1-docker.pkg.dev/checkpoint-distributor/distributor-docker-dev/feeder:latest"
    // We just want to update in the background, no need to send out a flood of requests.
    max_qps    = format("%0.2f", 1 / 30)
    extra_args = [for w in local.all_witness_urls : "--witness_url=${w}"]
    ephemeral  = true
  }
)

