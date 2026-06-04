# Copyright 2026 Czeslaw Szubert


# Environemnt variable based on folder name
locals {
  env = basename(abspath(path.module))
}

provider "google" {
  project = var.project
  region  = var.region
}

module "modules" {
  source = "../../modules"

  # cicd project variables
  env        = local.env
  project    = var.project
  region     = var.region
  
  # bootstrap pipeline variables
  platform_id                    = var.platform_id
  bootstrap_repo_owner = var.bootstrap_repo_owner
  bootstrap_repo_name  = var.bootstrap_repo_name
  
  # cicd pipeline variables
  cicd_repo_owner      = var.cicd_repo_owner
  cicd_repo_name       = var.cicd_repo_name

  # execution variables
  terraform_image      = var.terraform_image
}