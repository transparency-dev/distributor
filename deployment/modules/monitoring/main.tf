/**
 * Copyright 2024 Google LLC
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
      version = "5.14.0"
    }
  }
}

resource "google_project_service" "monitoring_api" {
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}

locals {
  distributor_service = "distributor-service-${var.env}"
  duration            = "5m"
}

resource "google_monitoring_alert_policy" "receiving_updates" {
  display_name = "Receiving Updates (${var.env})"
  combiner     = "OR"
  conditions {
    display_name = "Requests are present (${var.env})"
    condition_prometheus_query_language {
      query               = <<-EOT
sum(
  absent(distributor_update_checkpoint_request{service_name="${local.distributor_service}"})
  OR
  rate(distributor_update_checkpoint_request{service_name="${local.distributor_service}"}[${local.duration}]) == 0
)
EOT
      duration            = "1800s"
      evaluation_interval = "60s"
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "successful_updates" {
  display_name = "Successful Updates (${var.env})"
  combiner     = "OR"
  conditions {
    display_name = "Success ratio is healthy (${var.env})"
    condition_prometheus_query_language {
      query               = <<-EOT
sum(
  rate(distributor_update_checkpoint_success{service_name="${local.distributor_service}"}[${local.duration}])
  /
  rate(distributor_update_checkpoint_request{service_name="${local.distributor_service}"}[${local.duration}])
) < 0.5
EOT
      duration            = "1800s"
      evaluation_interval = "60s"
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}
