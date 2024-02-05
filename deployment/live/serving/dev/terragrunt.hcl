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
    env                      = "dev"
    distributor_docker_image = "us-central1-docker.pkg.dev/checkpoint-distributor/distributor-docker-dev/distributor:latest"
    extra_args               = [
      "--witkey=mhutchinson.witness+384b3dbc+AfWg+7+qmcFoMuIM0ZGe4ZsIuc6gEg3EL0cKkNVolCA+",
      "--witkey=wolsey-bank-alfred+0336ecb0+AVcofP6JyFkxhQ+/FK7omBtGLVS22tGC6fH+zvK5WrIx",
      "--witkey=JKU-INS+814e35bf+AdYBKkmgKGzao81EKOSxkphZLDtgBf72VXHFOIhMmqvO",
    ]
  }
)

