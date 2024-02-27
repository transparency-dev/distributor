include {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_path_to_repo_root()}/deployment/modules/distributor"
}

locals {
  env           = "dev"
  common_vars   = read_terragrunt_config(find_in_parent_folders())
  witnesses_raw = yamldecode(file("${get_path_to_repo_root()}/config/witnesses-${local.env}.yaml"))
  witnessArgs   = [for w in local.witnesses_raw.Witnesses : "--witkey=${w}"]
}

inputs = merge(
  local.common_vars.locals,
  {
    env                      = local.env
    distributor_docker_image = "us-central1-docker.pkg.dev/checkpoint-distributor/distributor-docker-dev/distributor:latest"
    extra_args               = local.witnessArgs
  }
)

