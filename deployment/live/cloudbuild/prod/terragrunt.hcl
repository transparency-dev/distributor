include "root" {
  path   = find_in_parent_folders()
  expose = true
}

inputs = merge(
  include.root.locals,
  {
    distributor_cloud_run_service = "distributor-service-ci"
    feeder_cloud_run_service      = "feeder-service-ci"
    slack_template_json           = file("slack.json")
  }
)

