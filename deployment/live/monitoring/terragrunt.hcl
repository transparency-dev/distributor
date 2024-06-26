terraform {
  source = "${get_repo_root()}/deployment/modules/monitoring"
}

locals {
  project_id               = "checkpoint-distributor"
  region                   = "us-central1"
  env                      = path_relative_to_include()
  alert_enable_num_witness = true
}

remote_state {
  backend = "gcs"

  config = {
    project  = local.project_id
    location = local.region
    bucket   = "${local.project_id}-monitoring-${local.env}-tfstate"
    prefix   = "${path_relative_to_include()}/terraform.tfstate"

    gcs_bucket_labels = {
      name  = "terraform_state_storage"
    }
  }
}
