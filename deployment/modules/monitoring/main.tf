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
  # Calculate the threshold for majority.
  # For odd numbers of devices, ceil(N/2) is fine, but if N is even we need to detect that and add 1:
  majority         = ceil(var.num_expected_devices / 2) + 1 - (ceil(var.num_expected_devices / 2) - floor(var.num_expected_devices / 2))
  majority_percent = local.majority / var.num_expected_devices * 100
}

resource "google_monitoring_dashboard" "witness_dashboard" {
  # Use 'map' in MQL to rename values:
  # https://stackoverflow.com/questions/70381209/gcp-mql-rename-a-line-in-monitoring-chart
  dashboard_json = <<-EOF
    {
      "displayName": "Armored Witness (${var.env})",
      "gridLayout": {
        "widgets": [
          {
            "title": "Update checkpoint success",
            "xyChart": {
              "dataSets": [{
                "timeSeriesQuery": {
                  "timeSeriesQueryLanguage": "fetch prometheus_target\n | metric 'prometheus.googleapis.com/distributor_update_checkpoint_success/counter' \n | filter (resource.namespace == 'distributor-service-${var.env}')\n | align rate(1m) \n | every 1m \n | group_by [metric.witness_id], \n [value_distributor_update_checkpoint_success_aggregate: aggregate(value.distributor_update_checkpoint_success)]\n | add [p: metric.witness_id] | map [p]"
                },
                "plotType": "LINE"
              }],
              "timeshiftDuration": "0s",
              "yAxis": {
                "label": "QPS",
                "scale": "LINEAR"
              }
            }
          },
          {
            "title": "Update checkpoint request",
            "xyChart": {
              "dataSets": [{
                "timeSeriesQuery": {
                  "timeSeriesQueryLanguage": "fetch prometheus_target\n | metric 'prometheus.googleapis.com/distributor_update_checkpoint_request/counter' \n | filter (resource.namespace == 'distributor-service-${var.env}')\n | align rate(1m) \n | every 1m \n | group_by [metric.witness_id], \n [value_distributor_update_checkpoint_request_aggregate: aggregate(value.distributor_update_checkpoint_request)]\n | add [p: metric.witness_id] | map [p]"
                },
                "plotType": "LINE"
              }],
              "timeshiftDuration": "0s",
              "yAxis": {
                "label": "QPS",
                "scale": "LINEAR"
              }
            }
          },
          {
            "title": "Devices seen online",
            "xyChart": {
              "dataSets": [{
                "timeSeriesQuery": {
                  "prometheusQuery": "count by (witness_id) (max by (instance_id, witness_id) (rate(distributor_update_checkpoint_request{configuration_name='distributor-service-${var.env}'}[$${__interval}]) > bool 0))"
                },
                "plotType": "STACKED_AREA"
              }],
              "thresholds": [{
                "value": ${local.majority}
              }],
              "timeshiftDuration": "0s",
              "yAxis": {
                "label": "Devices",
                "scale": "LINEAR"
              }
            }
          },
          {
            "title": "% online (assuming ${var.num_expected_devices} devices)",
            "xyChart": {
              "dataSets": [{
                "timeSeriesQuery": {
                  "prometheusQuery": "count by (instance_id) (max by (instance_id, witness_id) (rate(distributor_update_checkpoint_request{configuration_name='distributor-service-${var.env}'}[$${__interval}]) > bool 0)) * 100 / ${var.num_expected_devices}"
                },
                "plotType": "STACKED_AREA"
              }],
              "thresholds": [{
                "value": ${local.majority_percent}
              }],
              "timeshiftDuration": "0s",
              "yAxis": {
                "label": "%",
                "scale": "LINEAR"
              }
            }
          },
          {
            "title": "Witness liveness alert chart",
            "alertChart": {
              "name": "${google_monitoring_alert_policy.witness_liveness.name}"
            }
          }
        ]
      }
    }
    EOF
}

resource "google_monitoring_alert_policy" "witness_liveness" {
  enabled      = var.alert_enable_num_witness
  display_name = "Number of live witnesses (${var.env}) < ${var.alert_lt_num_witness_threshold}"
  combiner     = "OR"
  conditions {
    display_name = "Number of live witnesses < ${var.alert_lt_num_witness_threshold}"
    condition_monitoring_query_language {
      # First group by both witness_id and instanceId, since the metric for
      # each witness is reported by multiple instances. Then, since the
      # timeseries across instances overlap, take the average. This ensures
      # that the count for each witness is not double-counted across instances.
      # Finally, add all the counts together to compare against the threshold.
      query    = <<-EOT
        fetch prometheus_target
        | metric
            'prometheus.googleapis.com/distributor_update_checkpoint_success/counter'
        | filter (resource.namespace == 'distributor-service-${var.env}')
        | align rate(1m)
        | every 1m
        | group_by [metric.witness_id, metric.instanceId], [row_count: row_count()]
        | group_by [metric.witness_id], [row_count_mean: mean(row_count)]
        | group_by [], [value_witness_aggregate: aggregate(row_count_mean)]
        | lt(${var.alert_lt_num_witness_threshold})
      EOT
      duration = "1800s"
    }
  }
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
