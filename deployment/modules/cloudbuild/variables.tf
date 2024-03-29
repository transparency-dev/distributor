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

variable "project_id" {
  description = "The project ID to host the builds in"
  type        = string
}

variable "region" {
  description = "The region to host the builds in"
  type        = string
}

variable "env" {
  description = "Unique identifier for the env, e.g. ci or prod"
  type        = string
}

variable "cloud_run_service" {
  description = "The name of the cloud run service that new images should be pushed to"
  type        = string
}

variable "slack_template_json" {
  description = "Contents of the Slack template (https://cloud.google.com/build/docs/configuring-notifications/configure-slack#configuring_slack_notifications)"
  type        = string
  default     = ""
}

