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

## DB root password
resource "random_password" "db_root_pwd" {
  length  = 16
  special = false
}
resource "google_secret_manager_secret" "db_root_pass" {
  secret_id = "dbrootpasssecret"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager_api]
}
resource "google_secret_manager_secret_version" "db_root_pass_data" {
  secret      = google_secret_manager_secret.db_root_pass.id
  secret_data = random_password.db_root_pwd.result
}

# DB user name
locals {
  dbuser = "distributor-app"
}
resource "google_secret_manager_secret" "dbuser" {
  secret_id = "dbusersecret"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager_api]
}
resource "google_secret_manager_secret_version" "dbuser_data" {
  secret = google_secret_manager_secret.dbuser.id
  secret_data = local.dbuser
}

# DB user password
resource "random_password" "db_user_pwd" {
  length  = 16
  special = false
}
resource "google_secret_manager_secret" "dbpass" {
  secret_id = "dbpasssecret"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager_api]
}
resource "google_secret_manager_secret_version" "dbpass_data" {
  secret      = google_secret_manager_secret.dbpass.id
  secret_data = random_password.db_user_pwd.result
}

# Database name
resource "google_secret_manager_secret" "dbname" {
  secret_id = "dbnamesecret"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager_api]
}
resource "google_secret_manager_secret_version" "dbname_data" {
  secret      = google_secret_manager_secret.dbname.id
  secret_data = "distributor"
}

###
### Update service accounts to allow secret access
###
resource "google_secret_manager_secret_iam_member" "secretaccess_compute_dbname" {
  secret_id = google_secret_manager_secret.dbname.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com" # Project's compute service account
}
resource "google_secret_manager_secret_iam_member" "secretaccess_compute_dbuser" {
  secret_id = google_secret_manager_secret.dbuser.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com" # Project's compute service account
}
resource "google_secret_manager_secret_iam_member" "secretaccess_compute_dbpass" {
  secret_id = google_secret_manager_secret.dbpass.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com" # Project's compute service account
}

###
### Creates SQL instance (~15 minutes to fully spin up)
###
resource "google_sql_database_instance" "default" {
  name             = "distributor-mysql-instance-1"
  project          = var.project_id
  region           = var.region
  database_version = "MYSQL_8_0"
  root_password    = random_password.db_root_pwd.result

  settings {
    tier = "db-f1-micro"
  }
  # set `deletion_protection` to true, will ensure that one cannot accidentally delete this instance by
  # use of Terraform whereas `deletion_protection_enabled` flag protects this instance at the GCP level.
  deletion_protection = false
  depends_on          = [google_project_service.sqladmin_api]
}

resource "google_sql_database" "distributordb" {
  name     = "distributor"
  instance = google_sql_database_instance.default.name
  charset  = "utf8"
}

resource "google_sql_user" "db_user" {
  name     = local.dbuser
  instance = google_sql_database_instance.default.name
  password = random_password.db_user_pwd.result
}

###
### Set up Cloud Run service
###
resource "google_cloud_run_v2_service" "default" {
  name     = "distributor-service"
  location = "us-central1"

  template {
    containers {
      image = "gcr.io/trillian-opensource-ci/distributor:latest" # Image to deploy
      args  = [ "--use_cloud_sql" ]

      # Sets a environment variable for instance connection name
      env {
        name  = "INSTANCE_CONNECTION_NAME"
        value = google_sql_database_instance.default.connection_name
      }
      # Sets a secret environment variable for database user secret
      env {
        name = "DB_USER"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.dbuser.secret_id # secret name
            version = "latest"                                      # secret version number or 'latest'
          }
        }
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
      # Sets a secret environment variable for database name secret
      env {
        name = "DB_NAME"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.dbname.secret_id # secret name
            version = "latest"                                      # secret version number or 'latest'
          }
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.default.connection_name]
      }
    }
  }
  client     = "terraform"
  depends_on = [google_project_service.secretmanager_api, google_project_service.cloudrun_api, google_project_service.sqladmin_api]
}
