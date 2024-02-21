include {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_path_to_repo_root()}/deployment/modules/cloudbuild"
}

locals {
  common_vars = read_terragrunt_config(find_in_parent_folders())
}

inputs = merge(
  local.common_vars.locals,
  {
    env                 = "dev"
    cloud_run_service   = "distributor-service-dev"
    slack_template_json = file("slack.json")
  }
)

