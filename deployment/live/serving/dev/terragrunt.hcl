include "root" {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${get_repo_root()}/deployment/modules/distributor"
}

inputs = merge(
  include.root.locals,
  {
    distributor_docker_image = "us-central1-docker.pkg.dev/checkpoint-distributor/distributor-docker-dev/distributor:latest"
    extra_args               = include.root.locals.witnessArgs
  }
)

