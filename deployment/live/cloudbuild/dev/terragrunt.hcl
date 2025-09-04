include "root" {
  path   = find_in_parent_folders()
  expose = true
}

inputs = merge(
  include.root.locals,
  {
    distributor_cloud_run_service = "distributor-service-dev"
    witness_cloud_run_service     = "witness-service-dev"
    feeder_cloud_run_service     = "feeder-service-dev"
    slack_template_json           = file("slack.json")
  }
)

