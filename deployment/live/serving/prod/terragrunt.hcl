include {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_path_to_repo_root()}/deployment/modules/distributor"
}

locals {
  common_vars = read_terragrunt_config(find_in_parent_folders())
}

inputs = merge(
  local.common_vars.locals,
  {
    env                      = "prod"
    # TODO(mhutchinson): change this to tagged releases
    distributor_docker_image = "us-central1-docker.pkg.dev/checkpoint-distributor/distributor-docker-prod/distributor:latest"
  }
)

