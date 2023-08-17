locals {
  env = {
    default = {
      profile        = "nope"
      developers     = []
      public_subnets = []
    }
    sandbox = {
      start_cidr_range = "10.16.0.0/16"
      profile          = "de_sandbox"
      developers       = ["paul", "lucy", "adam", "john"]
      public_subnets   = ["10.16.24.0/21", "10.16.32.0/21", "10.16.40.0/21"]
    }
    majestic = {
      start_cidr_range = "10.17.0.0/16"
      profile          = "majestic"
      developers       = ["robertf", "ivans"]
      public_subnets   = ["10.17.24.0/21", "10.17.32.0/21", "10.17.40.0/21"]
    }
  }
  environmentvars = contains(keys(local.env), terraform.workspace) ? terraform.workspace : "default"
  workspace       = merge(local.env["default"], local.env[local.environmentvars])
}