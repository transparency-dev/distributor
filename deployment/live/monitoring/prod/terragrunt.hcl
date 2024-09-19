include "root" {
  path   = find_in_parent_folders()
  expose = true
}

inputs = merge(
  include.root.locals,
  {
    alert_lt_num_witness_threshold = 10
    alert_enable_num_witness = false
    num_expected_devices = 15
  }
)

