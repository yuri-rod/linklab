terraform {
  source = "../../../modules/rds"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  identifier = "linklab-dev"
  db_name    = "linklab"
  username   = "linklab"
  password   = get_env("DB_PASSWORD", "CHANGEME_DEV_PASSWORD")
  subnet_ids = dependency.vpc.outputs.private_subnet_ids
}
