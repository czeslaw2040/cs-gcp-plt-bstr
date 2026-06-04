# Copyright 2026 Czeslaw Szubert


# This file is intended for global variables that are shared across ALL environments.
# The Cloud Build pipeline passes this file to Terraform using the '-var-file' argument.
#
# Note: Environment specific variables are specified in the environment's 'terraform.tfvars' file 
#     (e.g., environments/dev/terraform.tfvars).


# ==============================================================================
# Platform Configuration
# ==============================================================================
# platform_id: Unique identifier for the platform.
# Used for standard nomenclature when creating GitHub repositories, GCP projects and
# platform shared resources.
# NOTE: Must use only lowercase letters, numbers, and hyphens, begin with a letter, 
# and be no more than 15 characters long.
platform_id = "my-plt"


# ==============================================================================
# Bootstrap Git repository Configuration
# ==============================================================================
bootstrap_repo_owner = "github-user"
bootstrap_repo_name  = "my-plt-bstr"


# ==============================================================================
# CICD Git repository Configuration
# ==============================================================================
cicd_repo_owner  = "github-user"
cicd_repo_name   = "my-plt-cicd"

# ==============================================================================
# Terraform Execution Configuration
# ==============================================================================
# terraform_image: Docker image and version used to execute Terraform steps in the Cloud Build pipeline.
# NOTE: Update regularly and pin to current stable version as needed.
terraform_image = "hashicorp/terraform:1.15.0"
