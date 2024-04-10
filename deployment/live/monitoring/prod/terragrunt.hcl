include "root" {
  path   = find_in_parent_folders()
  expose = true
}

inputs = merge(
  include.root.locals,
  {
    lt_num_witness_threshold = 10
  }
)

