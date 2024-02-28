include "root" {
  path   = find_in_parent_folders()
  expose = true
}

inputs = merge(
  include.root.locals,
  {
    distributor_docker_image = "us-central1-docker.pkg.dev/checkpoint-distributor/distributor-docker-prod/distributor:latest"
    extra_args               = include.root.locals.witnessArgs
  }
)

