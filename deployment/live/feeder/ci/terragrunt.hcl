include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  ci_aw_ids = [
    "76d180a9d59ea2165ba4417d96ff26f79f938116129519ec85f2a39473c65cb9",
    "1decd179ab5784e3f8ee689af2d3b353ca8ce4d1e25abe8b50b9376af32233b7",
    "66cea1a2e93c90692a697c4f36418f38d72287f65c842b883f3343bb0e27ab44",
    "60be39b9426e7777190bc89af9b568021c1610cb9067cac15a1c30f188042a52",
    "c412b97bcc4d8bac24be24f51931a009488e0e85a21bdba9d2f0c72c0d406a86",
    "ea8a7b22bb1a6420464bab7a01f768f120cf237bb399b46d0973109059175264",
  ]
  ci_bastion_base = "https://bastion.glasklar.is"
  ci_witness_urls = [for i in local.ci_aw_ids : format("%s/%s", local.ci_bastion_base, i)]

  all_witness_urls = local.ci_witness_urls
}

inputs = merge(
  include.root.locals,
  {
    feeder_docker_image = "us-central1-docker.pkg.dev/checkpoint-distributor/distributor-docker-dev/feeder:latest"
    // We just want to update in the background, no need to send out a flood of requests.
    max_qps    = format("%0.2f", 1 / 30)
    extra_args = [for w in local.all_witness_urls : "--witness_url=${w}"]
    ephemeral  = true
  }
)

