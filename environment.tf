locals {
  env = {
    default = {
      profile        = "placeholder"
      developers     = []
      public_subnets = []
    }
    sandbox = {
      start_cidr_range = "10.16.0.0/16"
      profile          = "sandbox"
      developers       = ["paul", "lucy", "adam"]
      public_subnets   = ["10.16.24.0/21", "10.16.32.0/21", "10.16.40.0/21"]
    }
    acme = {
      start_cidr_range = "10.17.0.0/16"
      profile          = "acme"
      developers       = ["paul", "lucy"]
      public_subnets   = ["10.17.24.0/21", "10.17.32.0/21", "10.17.40.0/21"]
    }
  }
  env_vars  = contains(keys(local.env), terraform.workspace) ? terraform.workspace : "default"
  workspace = merge(local.env["default"], local.env[local.env_vars])
}