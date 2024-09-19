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
  description = "The project ID to host the cluster in"
  type        = string
}

variable "region" {
  description = "The region to host the cluster in"
  type        = string
}

variable "env" {
  description = "Unique identifier for the env, e.g. ci or prod"
  type        = string
}

variable "num_expected_devices" {
  description = "Number of expected devices"
  type        = number
}

variable "alert_lt_num_witness_threshold" {
  description = "The lower bound alert threshold for the number of live witnesses, as measured by the distributor_update_checkpoint_success Prometheus metric."
  type        = number
}

variable "alert_enable_num_witness" {
  description = "Whether to enable alert_lt_num_witness_threshold."
  type        = bool
}
