/*
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# Project data
provider "google" {
  project = var.project_id
}

data "google_project" "project" {
  project_id = var.project_id
}

# This will be configured by terragrunt when deploying
terraform {
  backend "gcs" {}
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

# Enable Secret Manager API
resource "google_project_service" "secretmanager_api" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Enable Spanner
resource "google_project_service" "spanner_api" {
  service            = "spanner.googleapis.com"
  disable_on_destroy = false
}

# Enable Cloud Run API
resource "google_project_service" "cloudrun_api" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

data "google_secret_manager_secret" "witness_secret" {
  secret_id = "witness_secret_${var.env}"
}

data "google_secret_manager_secret_version" "witness_secret_data" {
  secret = data.google_secret_manager_secret.witness_secret.id
}

# Update service accounts to allow secret access
resource "google_secret_manager_secret_iam_member" "secretaccess_compute_witness" {
  secret_id = data.google_secret_manager_secret.witness_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com" # Project's compute service account
}

resource "google_spanner_instance" "witness_spanner" {
  name             = "witness-${var.env}"
  config           = "regional-${var.region}"
  display_name     = "Witness ${var.env}"
  processing_units = 100

  force_destroy = var.ephemeral
  depends_on = [
    google_project_service.spanner_api,
  ]
}

resource "google_spanner_database" "witness_db" {
  instance = google_spanner_instance.witness_spanner.name
  name     = "witness_db_${var.env}"

  deletion_protection = !var.ephemeral
}

resource "google_spanner_database_iam_member" "database" {
  instance = google_spanner_instance.witness_spanner.name
  database = google_spanner_database.witness_db.name
  role     = "roles/spanner.databaseAdmin"

  member = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com" # Project's compute service account
}

locals {
  spanner_db_full = "projects/${var.project_id}/instances/${google_spanner_instance.witness_spanner.name}/databases/${google_spanner_database.witness_db.name}"
}

###
### Set up Cloud Run service
###
resource "google_service_account" "cloudrun_service_account" {
  account_id   = "cloudrun-witness-${var.env}-sa"
  display_name = "Service Account for Witness Cloud Run (${var.env})"
}

resource "google_project_iam_member" "iam_act_as" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloudrun_service_account.email}"
}
resource "google_project_iam_member" "iam_metrics_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cloudrun_service_account.email}"
}
resource "google_project_iam_member" "iam_spanner_client" {
  project = var.project_id
  role    = "roles/spanner.databaseUser"
  member  = "serviceAccount:${google_service_account.cloudrun_service_account.email}"
}
resource "google_project_iam_member" "iam_service_agent" {
  project = var.project_id
  role    = "roles/run.serviceAgent"
  member  = "serviceAccount:${google_service_account.cloudrun_service_account.email}"
}
resource "google_project_iam_member" "iam_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudrun_service_account.email}"
}

resource "google_cloud_run_v2_service" "default" {
  name         = "witness-service-${var.env}"
  location     = var.region
  launch_stage = "GA"


  template {
    service_account = google_service_account.cloudrun_service_account.email
    scaling {
      min_instance_count = 1
      max_instance_count = 3
    }
    max_instance_request_concurrency = 1000
    containers {
      image = var.witness_docker_image
      name  = "witness"
      args = concat([
        "--logtostderr",
        "--v=1",
        "--listen=:8090",
        "--spanner=${local.spanner_db_full}",
        "--signer_private_key_secret_name=${data.google_secret_manager_secret_version.witness_secret_data.name}"
      ], var.extra_args)
      ports {
        container_port = 8090
      }

      startup_probe {
        initial_delay_seconds = 1
        timeout_seconds       = 1
        period_seconds        = 10
        failure_threshold     = 3
        tcp_socket {
          port = 8090
        }
      }
    }
    containers {
      image      = "us-docker.pkg.dev/cloud-ops-agents-artifacts/cloud-run-gmp-sidecar/cloud-run-gmp-sidecar:1.0.0"
      name       = "collector"
      depends_on = ["witness"]
    }
  }
  client = "terraform"
  depends_on = [
    google_project_service.secretmanager_api,
    google_project_service.cloudrun_api,
    google_project_service.spanner_api,
    google_project_iam_member.iam_act_as,
    google_project_iam_member.iam_metrics_writer,
    google_project_iam_member.iam_spanner_client,
    google_project_iam_member.iam_service_agent,
    google_project_iam_member.iam_secret_accessor,
  ]

  deletion_protection = !var.ephemeral
}

resource "google_cloud_run_service_iam_binding" "default" {
  location = google_cloud_run_v2_service.default.location
  service  = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]
}

