terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.14.0"
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
  location       = var.region
  description   = "docker images for the distributor"
  format        = "DOCKER"
}

locals {
  artifact_repo  = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.distributor_docker.name}"
  docker_address = "${local.artifact_repo}/distributor:latest"
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

  # TODO(mhutchinson): Consider replacing this with https://github.com/ko-build/terraform-provider-ko
  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "-t", "${local.docker_address}",
        "-f", "./cmd/Dockerfile",
        "."
      ]
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        local.docker_address
      ]
    }
    # Deploy container image to Cloud Run
    step {
      name       = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      entrypoint = "gcloud"
      args       = [
        "run",
        "deploy",
        var.cloud_run_service,
        "--image",
        local.docker_address,
        "--region",
        var.region
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
  # This should be set back to the registry version when the following is merged:
  # https://github.com/simplifi/terraform-google-cloud-build-slack-notifier/pull/8
  source     = "github.com/mhutchinson/terraform-google-cloud-build-slack-notifier"
  # source  = "simplifi/cloud-build-slack-notifier/google"
  # version = "0.3.0"

  name       = "gcp-slack-notifier-${var.env}"
  project_id = var.project_id
  
  # https://api.slack.com/apps/A06KYD43DPE/incoming-webhooks
  slack_webhook_url_secret_id      = "gcb_slack_webhook_${var.env}"
  slack_webhook_url_secret_project = var.project_id
}

