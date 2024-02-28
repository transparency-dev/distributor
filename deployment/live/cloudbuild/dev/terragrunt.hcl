include "root" {
  path   = find_in_parent_folders()
  expose = true
}

inputs = merge(
  include.root.locals,
  {
    cloud_run_service   = "distributor-service-dev"
    slack_template_json = file("slack.json")
  }
)

