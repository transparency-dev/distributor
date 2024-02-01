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
  name     = "build-distributor-docker-${var.env}"
  location = var.region

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
  }
}
