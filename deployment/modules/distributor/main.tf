/**
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
      source = "hashicorp/google"
      version = "5.14.0"
    }
  }
}

# Enable Secret Manager API
resource "google_project_service" "secretmanager_api" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Enable SQL Admin API
resource "google_project_service" "sqladmin_api" {
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

# Enable Cloud Run API
resource "google_project_service" "cloudrun_api" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

###
### Create secrets
###

# DB user password
resource "random_password" "db_user_pwd" {
  length  = 32
  special = false
}
resource "google_secret_manager_secret" "dbpass" {
  secret_id = "dbpasssecret_${var.env}"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager_api]
}
resource "google_secret_manager_secret_version" "dbpass_data" {
  secret      = google_secret_manager_secret.dbpass.id
  secret_data = random_password.db_user_pwd.result
}
# Update service accounts to allow secret access
resource "google_secret_manager_secret_iam_member" "secretaccess_compute_dbpass" {
  secret_id = google_secret_manager_secret.dbpass.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com" # Project's compute service account
}

resource "random_id" "suffix" {
  byte_length = 5
}

locals {
  /*
    Random instance name needed because:
    "You cannot reuse an instance name for up to a week after you have deleted an instance."
    See https://cloud.google.com/sql/docs/mysql/delete-instance for details.
  */
  network_name = "${var.network_name}-safer-${var.env}-${random_id.suffix.hex}"
}

###
### Networking
###
module "network-safer-mysql-simple" {
  source  = "terraform-google-modules/network/google"
  version = "9.0.0"

  project_id   = var.project_id
  network_name = local.network_name

  subnets = [
  ]
}

module "private-service-access" {
  source      = "GoogleCloudPlatform/sql-db/google//modules/private_service_access"
  project_id  = var.project_id
  vpc_network = module.network-safer-mysql-simple.network_name
}

locals {
  dbname = "distributor"
  dbuser = "distributor-app"
}

module "safer-mysql-db" {
  source               = "GoogleCloudPlatform/sql-db/google//modules/safer_mysql"
  name                 = "distributor-mysql-${var.env}-instance-1"
  random_instance_name = true
  project_id           = var.project_id

  deletion_protection = false

  database_version = "MYSQL_8_0"
  region           = var.region
  zone             = "${var.region}-c"
  tier             = "db-n1-standard-1"
  assign_public_ip = "true"
  vpc_network      = module.network-safer-mysql-simple.network_self_link

  user_name     = local.dbuser
  user_password = random_password.db_user_pwd.result

  additional_databases = [
    {
      name      = local.dbname,
      charset   = "",
      collation = "",
    },
  ]

  // Optional: used to enforce ordering in the creation of resources.
  module_depends_on = [module.private-service-access.peering_completed]
}

###
### Set up Cloud Run service
###
resource "google_service_account" "cloudrun_service_account" {
  account_id   = "cloudrun-${var.env}-sa"
  display_name = "Service Account for Cloud Run (${var.env})"
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
resource "google_project_iam_member" "iam_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
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
  name         = "distributor-service-${var.env}"
  location     = var.region
  launch_stage = "GA"

  template {
    service_account = google_service_account.cloudrun_service_account.email
    containers {
      image = var.distributor_docker_image
      name  = "distributor"
      args  = concat([
        "--logtostderr",
        "--v=1",
        "--use_cloud_sql",
      ], var.extra_args)
      ports {
        container_port = 8080
      }

      env {
        name  = "INSTANCE_CONNECTION_NAME"
        value = module.safer-mysql-db.instance_connection_name
      }
      env {
        name  = "DB_NAME"
        value = local.dbname
      }
      env {
        name  = "DB_USER"
        value = local.dbuser
      }
      # Sets a secret environment variable for database password secret
      env {
        name = "DB_PASS"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.dbpass.secret_id # secret name
            version = "latest"                                      # secret version number or 'latest'
          }
        }
      }

      startup_probe {
        initial_delay_seconds = 1
        timeout_seconds = 1
        period_seconds = 10
        failure_threshold = 3
        tcp_socket {
          port = 8080
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }
    containers {
      image = "us-docker.pkg.dev/cloud-ops-agents-artifacts/cloud-run-gmp-sidecar/cloud-run-gmp-sidecar:1.0.0"
      name  = "collector"
      depends_on = ["distributor"]
    }
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [module.safer-mysql-db.instance_connection_name]
      }
    }
  }
  client     = "terraform"
  depends_on = [
    google_project_service.secretmanager_api,
    google_project_service.cloudrun_api,
    google_project_service.sqladmin_api,
    google_project_iam_member.iam_act_as,
    google_project_iam_member.iam_metrics_writer,
    google_project_iam_member.iam_sql_client,
    google_project_iam_member.iam_service_agent,
    google_project_iam_member.iam_secret_accessor,
  ]
}

resource "google_cloud_run_service_iam_binding" "default" {
  location = google_cloud_run_v2_service.default.location
  service  = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]
}

