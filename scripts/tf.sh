#!/bin/bash

# Copyright 2026 Czeslaw Szubert


# ==============================================================================
# Manual Terraform Execution Helper
# ==============================================================================
# This script helps execute Terraform commands manually after the initial 
# bootstrap. It automatically runs 'terraform init' with the correct remote 
# GCS backend configuration for the specified environment before executing 
# your target command.
#
# Usage:
#   ./scripts/tf.sh <environment> <terraform_command> [additional_args...]
#
# Examples:
#   ./scripts/tf.sh dev plan
#   ./scripts/tf.sh dev apply
#   ./scripts/tf.sh dev destroy
#       NOTE: See ALLOW_PROD_DESTROY section below for safety measures when running destroy.
# ==============================================================================


# ==============================================================================
# Variables Parsed from Configuration Files
# ==============================================================================
# This script extracts the following variables from configuration files:
# - PROJECT_ID: Parsed from the 'project' variable in the environment's 
#               terraform.tfvars file (environments/<environment>/terraform.tfvars).
#               Used to construct the GCS state bucket name in the backend configuration.
# - PIPELINE_ID: Constructed from the 'platform_id' variable in the tfvars files.
#                Used to construct the state path (prefix) in the GCS bucket.
# ==============================================================================


# ==============================================================================
# Terraform Variables Configuration
# ==============================================================================
# This script uses two variable files during Terraform operations:
# 1. Global variables: environments/terraform.tfvars (passed as ../terraform.tfvars)
# 2. Environment-specific variables: environments/<environment>/terraform.tfvars
#    Implicitly included in terraform commands because the file is located 
#    in the current directory where terraform is executed.
# ==============================================================================


# ==============================================================================
# *** ALLOW_PROD_DESTROY ***
# To allow destroying prod, uncomment the following line:
# ALLOW_PROD_DESTROY="true"
# ==============================================================================


# Exit immediately if a command exits with a non-zero status
set -e

ENVIRONMENT=$1
COMMAND=$2

if [ -z "$ENVIRONMENT" ] || [ -z "$COMMAND" ]; then
  echo "Usage: $0 <environment> <terraform_command> [additional_args...]"
  echo "Example: $0 dev plan"
  echo "Example: $0 dev apply"
  echo "Example: $0 dev destroy"
  exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "$ENVIRONMENT" ]; then
  echo "Error: Current git branch '$CURRENT_BRANCH' does not match the specified environment '$ENVIRONMENT'."
  echo "Please checkout the correct branch and try again."
  exit 1
fi

ENV_DIR="environments/${ENVIRONMENT}"
TFVARS_FILE="${ENV_DIR}/terraform.tfvars"
GLOBAL_TFVARS_FILE="environments/terraform.tfvars"

if [ ! -d "$ENV_DIR" ]; then
  echo "Error: Environment directory '$ENV_DIR' does not exist."
  exit 1
fi

if [ ! -f "$TFVARS_FILE" ]; then
  echo "Error: TFVARS file not found at ${TFVARS_FILE}"
  exit 1
fi

if [ ! -f "$GLOBAL_TFVARS_FILE" ]; then
  echo "Error: Global TFVARS file not found at ${GLOBAL_TFVARS_FILE}"
  exit 1
fi

PROJECT_ID=$(grep -E '^\s*project\s*=' "$TFVARS_FILE" | awk -F'"' '{print $2}')
if [ -z "$PROJECT_ID" ]; then
  echo "Error: Could not parse 'project' variable from ${TFVARS_FILE}"
  exit 1
fi

PLATFORM_ID=$(cat "$GLOBAL_TFVARS_FILE" "$TFVARS_FILE" 2>/dev/null | grep -E '^\s*platform_id\s*=' | head -n 1 | awk -F'"' '{print $2}')
if [ -z "$PLATFORM_ID" ]; then
  echo "Error: Could not parse 'platform_id' from tfvars files"
  exit 1
fi

SANITIZED_PLATFORM_ID=$(echo "$PLATFORM_ID" | tr '_' '-' | cut -c1-15)
PIPELINE_ID="${SANITIZED_PLATFORM_ID}-bstr"

cd "$ENV_DIR"

# Shift first two arguments (env and command) so we can pass the rest to terraform
shift 2

if [ "$COMMAND" = "init" ]; then
  echo "Error: 'init' is automatically executed by this script. Please pass the target command (e.g., plan, apply, destroy)."
  exit 1
fi

echo "Initializing Terraform..."
terraform init -backend-config="bucket=${PROJECT_ID}-tfstate" -backend-config="prefix=${PIPELINE_ID}/${ENVIRONMENT}"

echo "Running Terraform ${COMMAND}..."
if [ "$COMMAND" = "destroy" ]; then
  if [ "$ENVIRONMENT" = "prod" ]; then
    if [ "$ALLOW_PROD_DESTROY" != "true" ]; then
      echo "***************************** ERROR *******************************"
      echo "Destroy action is forbidden on the 'prod' environment by default."
      echo "To override, uncomment 'ALLOW_PROD_DESTROY' in tf.sh."
      echo "*******************************************************************"
      exit 1
    fi
    echo "WARNING: Proceeding with PROD destruction as explicitly permitted by 'ALLOW_PROD_DESTROY' variable."
  fi

  read -p "Are you sure you want to run destroy? Enter 'destroy' to continue: " CONFIRM_DESTROY
  if [ "$CONFIRM_DESTROY" != "destroy" ]; then
    echo "Aborting destroy operation."
    exit 1
  fi
fi

terraform "$COMMAND" -var-file=../terraform.tfvars "$@"