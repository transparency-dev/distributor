terraform {
  source = "${get_repo_root()}/deployment/modules/distributor"
}

locals {
  project_id  = "checkpoint-distributor"
  region      = "us-central1"
  env         = path_relative_to_include()
  witnesses_raw = yamldecode(file("${get_repo_root()}/config/witnesses-${local.env}.yaml"))
  witnessArgs   = [for w in local.witnesses_raw.Witnesses : "--witkey=${w}"]
}

remote_state {
  backend = "gcs"

  config = {
    project  = local.project_id
    location = local.region
    bucket   = "${local.project_id}-serving-${local.env}-terraform-state"
    prefix   = "${path_relative_to_include()}/terraform.tfstate"

    gcs_bucket_labels = {
      name  = "terraform_state_storage"
    }
  }
}
