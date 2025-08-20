terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.0.1"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "6.0.1"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# This will be configured by terragrunt when deploying
terraform {
  backend "gcs" {}
}

resource "google_artifact_registry_repository" "distributor_docker" {
  repository_id = "distributor-docker-${var.env}"
  location      = var.region
  description   = "docker images for the distributor"
  format        = "DOCKER"
}

locals {
  artifact_repo = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.distributor_docker.name}"
  distributor_docker_image  = "${local.artifact_repo}/distributor"
  witness_docker_image  = "${local.artifact_repo}/witness"
}

resource "google_cloudbuild_trigger" "distributor_docker" {
  name            = "build-distributor-docker-${var.env}"
  service_account = google_service_account.cloudbuild_service_account.id
  location        = var.region

  github {
    owner = "transparency-dev"
    name  = "distributor"
    push {
      branch = "^main$"
    }
  }

  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "-t", "${local.distributor_docker_image}:$SHORT_SHA",
        "-t", "${local.distributor_docker_image}:latest",
        "-f", "./cmd/Dockerfile",
        "."
      ]
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "--all-tags",
        local.distributor_docker_image
      ]
    }
    # Deploy container image to Cloud Run
    step {
      name       = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      entrypoint = "gcloud"
      args = [
        "run",
        "deploy",
        var.distributor_cloud_run_service,
        "--image",
        "${local.distributor_docker_image}:$SHORT_SHA",
        "--region",
        var.region
      ]
    }
    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }
}

# When a new tag is pushed to GitHub, add that tag to the docker
# image that was already pushed to the repo for the corresponding
# commit hash.
# This requires that the above step has already completed, but that
# seems like a fair assumption given that we'd have deployed it in ci
# before tagging it.
resource "google_cloudbuild_trigger" "distributor_docker_tag" {
  name            = "tag-distributor-docker-${var.env}"
  service_account = google_service_account.cloudbuild_service_account.id
  location        = var.region

  github {
    owner = "transparency-dev"
    name  = "distributor"
    push {
      tag = ".*"
    }
  }

  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "pull",
        "${local.distributor_docker_image}:$SHORT_SHA",
      ]
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "tag",
        "${local.distributor_docker_image}:$SHORT_SHA",
        "${local.distributor_docker_image}:$TAG_NAME",
      ]
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${local.distributor_docker_image}:$TAG_NAME",
      ]
    }
    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }
}

resource "google_cloudbuild_trigger" "witness_docker" {
  name            = "build-witness-docker-${var.env}"
  service_account = google_service_account.cloudbuild_service_account.id
  location        = var.region

  github {
    owner = "transparency-dev"
    name  = "witness"
    push {
      branch = "^main$"
    }
  }

  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "-t", "${local.witness_docker_image}:$SHORT_SHA",
        "-t", "${local.witness_docker_image}:latest",
        "-f", "./cmd/gcp/omniwitness/Dockerfile",
        "."
      ]
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "--all-tags",
        local.witness_docker_image
      ]
    }
    # Deploy container image to Cloud Run
    step {
      name       = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      entrypoint = "gcloud"
      args = [
        "run",
        "deploy",
        var.witness_cloud_run_service,
        "--image",
        "${local.witness_docker_image}:$SHORT_SHA",
        "--region",
        var.region
      ]
    }
    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }
}

# When a new tag is pushed to GitHub, add that tag to the docker
# image that was already pushed to the repo for the corresponding
# commit hash.
# This requires that the above step has already completed, but that
# seems like a fair assumption given that we'd have deployed it in ci
# before tagging it.
resource "google_cloudbuild_trigger" "witness_docker_tag" {
  name            = "tag-witness-docker-${var.env}"
  service_account = google_service_account.cloudbuild_service_account.id
  location        = var.region

  github {
    owner = "transparency-dev"
    name  = "witness"
    push {
      tag = ".*"
    }
  }

  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "pull",
        "${local.witness_docker_image}:$SHORT_SHA",
      ]
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "tag",
        "${local.witness_docker_image}:$SHORT_SHA",
        "${local.witness_docker_image}:$TAG_NAME",
      ]
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${local.witness_docker_image}:$TAG_NAME",
      ]
    }
    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }
}


resource "google_service_account" "cloudbuild_service_account" {
  account_id   = "cloudbuild-${var.env}-sa"
  display_name = "Service Account for CloudBuild (${var.env})"
}

resource "google_project_iam_member" "act_as" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
}

resource "google_project_iam_member" "logs_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
}

resource "google_project_iam_member" "artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
}

resource "google_project_iam_member" "cloudrun_deployer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
}

module "cloud-build-slack-notifier" {
  source  = "simplifi/cloud-build-slack-notifier/google"
  version = "0.4.0"

  name       = "gcp-slack-${var.env}"
  project_id = var.project_id

  cloud_build_event_filter = "build.substitutions['BRANCH_NAME'] == 'main' && build.status in [Build.Status.SUCCESS, Build.Status.FAILURE, Build.Status.TIMEOUT] && build.substitutions['TRIGGER_NAME'].endsWith('-${var.env}')"

  # https://api.slack.com/apps/A06KYD43DPE/incoming-webhooks
  slack_webhook_url_secret_id      = "gcb_slack_webhook_${var.env}"
  slack_webhook_url_secret_project = var.project_id

  override_slack_template_json = var.slack_template_json
}

