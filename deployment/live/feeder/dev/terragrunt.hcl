include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  dev_witness_urls = [
    "https://api.transparency.dev/dev/witness/little-garden",
  ]

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

  prod_aw_ids = [
    "2d01a87850deb2b3dff94013d2d4d280504a2e72618940b8ee151c999bc42830",
    "c664d70dc8cd2cbe40469224c66dd705d6eb67615c406b61a2579966127d0c7e",
    "395c4b740cfbb722a66cbb1790bb9e70100e35518c8101b3dacf579765e4d220",
    "2867895f07dfc47299cf7d2ced88ed5230a822a7f62d54f8402d6daf11520131",
    "a3924e97756d78c4e1ae3f30b55fc508b3cc84c7fbab002334b2617143ce9009",
    "5d4a576817f975218bf4f9ff8cf4400c2ee322f40c58a5ef2120d44d161d6f37",
    "92c1c586ab85db6af4c27fc714c49a080366eb5e4d7f5b696eadb7e845e78362",
    "b6d4eee9d6165e01a756bd4590ab29bc34265e2e83b580f54a19f4a458778cbc",
    "9e18b190f219d9a9d3032d8b00807aa0c014948fb324d543057d82afa00ad15c",
    "6365b85463db655dd4e224bdffa3dfd49fd49c9588b800718b4483799c324f5b",
    "c77fe626a6b4d53738a9a37920095ee205eb48d1717c19092c4c25efe2f2cc50",
    "989bb3b71551f35503b2a89798959f1a5d6e4cad2699133b2b49e54bc2a4fa68",
    "ff7a3001c5895b13144b68a421e13513d94c40b151e0e22d56fcceb14f802c18",
    "2777010fe71082f771ac21d700bd9f2ea55b5d8520d329a67867edcdb61e2fc2",
    "478f82d5b9a76aa5b907f5ef52bd5a3b8f5e12353ef01ae16e9aa0d74979b9db",
  ]
  prod_bastion_base = "https://bastion.glasklar.is"
  prod_witness_urls = [for i in local.prod_aw_ids : format("%s/%s", local.prod_bastion_base, i)]

  all_witness_urls = setunion(local.dev_witness_urls, local.ci_witness_urls, local.prod_witness_urls)

  // We just want to update in the background, no need to send out a flood of requests.
  max_qps = format("%0.2f", 1 / 30)
}

inputs = merge(
  include.root.locals,
  {
    feeder_docker_image = "us-central1-docker.pkg.dev/checkpoint-distributor/distributor-docker-dev/feeder:latest"
    extra_args = concat(
      [for w in local.all_witness_urls : "--witness_url=${w}"],
      [
        "--max_qps=${local.max_qps}",
      ]
    )
    ephemeral = true
  }
)

