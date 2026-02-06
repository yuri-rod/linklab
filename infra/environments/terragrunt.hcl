locals {
  region     = "us-east-1"
  project    = "linklab"
  bucket     = "linklab-terraform-state"
  dynamodb   = "linklab-terraform-lock"
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = local.bucket
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    dynamodb_table = local.dynamodb
    encrypt        = true
  }
}

inputs = {
  project = local.project
  region  = local.region
}
