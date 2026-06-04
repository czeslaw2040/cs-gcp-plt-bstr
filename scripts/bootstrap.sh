#!/bin/bash

# Copyright 2026 Czeslaw Szubert


# ==============================================================================
# GCP Project Bootstrap Script
# ==============================================================================
# This script automates the initial Terraform setup for a GCP project environment.
# It temporarily disables the remote backend to perform a local state apply, 
# creating remote state storage resources (GCS buckets). It then restores the 
# backend configuration and migrates the local state to the newly created GCS backend.
#
# Usage:
#   ./scripts/bootstrap.sh <environment>
#
# Example:
#   ./scripts/bootstrap.sh dev
# ==============================================================================

# ==============================================================================
# Variables Parsed from Configuration Files
# ==============================================================================
# This script extracts the following variables from configuration files:
# - PROJECT_ID: Parsed from the 'project' variable in the environment's 
#               terraform.tfvars file (environments/<environment>/terraform.tfvars).
#               Used to set the active gcloud project and name the GCS state bucket name.
# - PIPELINE_ID: Constructed from the 'platform_id' variable in the tfvars files.
#                Used to construct the state path (prefix) in the GCS bucket.
# - REGION: Parsed from the 'region' variable in the environment's terraform.tfvars file.
#           Used to generate the correct region-specific Cloud Console URL.
# - BOOTSTRAP_REPO_OWNER: Parsed from 'bootstrap_repo_owner' in the global terraform.tfvars file.
#                         Used in the user prompt for repository connection.
# - BOOTSTRAP_REPO_NAME: Parsed from 'bootstrap_repo_name' in the global terraform.tfvars file.
#                        Used in the user prompt for repository connection.
# - CICD_REPO_OWNER: Parsed from 'cicd_repo_owner' in the global terraform.tfvars file.
#                        Used in the user prompt for repository connection.
# - CICD_REPO_NAME: Parsed from 'cicd_repo_name' in the global terraform.tfvars file.
#                       Used in the user prompt for repository connection.
# ==============================================================================


# ==============================================================================
# Terraform Variables Configuration
# ==============================================================================
# This script uses two variable files during Terraform operations:
# 1. Global variables: environments/terraform.tfvars (passed as ../terraform.tfvars)
# 2. Environment-specific variables: environments/<environment>/terraform.tfvars
# ==============================================================================


# Exit immediately if a command exits with a non-zero status
set -e

# Forcing user to provide the environment enables checking that the correct git branch was selected.
ENVIRONMENT=$1

if [ -z "$ENVIRONMENT" ]; then
  echo "Usage: $0 <environment>"
  echo "Example: $0 dev"
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

# Parse the project ID from the environment's terraform.tfvars file
PROJECT_ID=$(grep -E '^\s*project\s*=' "$TFVARS_FILE" | awk -F'"' '{print $2}')

if [ -z "$PROJECT_ID" ]; then
  echo "Error: Could not parse 'project' variable from ${TFVARS_FILE}"
  exit 1
fi

# Parse PLATFORM_ID from tfvars files
PLATFORM_ID=$(cat "$GLOBAL_TFVARS_FILE" "$TFVARS_FILE" 2>/dev/null | grep -E '^\s*platform_id\s*=' | head -n 1 | awk -F'"' '{print $2}')

if [ -z "$PLATFORM_ID" ]; then
  echo "Error: Could not parse 'platform_id' from tfvars files"
  exit 1
fi

SANITIZED_PLATFORM_ID=$(echo "$PLATFORM_ID" | tr '_' '-' | cut -c1-15)
PIPELINE_ID="${SANITIZED_PLATFORM_ID}-bstr"

echo "Setting gcloud config project to ${PROJECT_ID}..."
gcloud config set project "$PROJECT_ID"

# Get the project number using gcloud
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

if [ -z "$PROJECT_NUMBER" ]; then
  echo "Error: Could not retrieve project number for ${PROJECT_ID} using gcloud."
  exit 1
fi

# Parse region from the environment's terraform.tfvars file
REGION=$(grep -E '^\s*region\s*=' "$TFVARS_FILE" | awk -F'"' '{print $2}')
if [ -z "$REGION" ]; then
  echo "Error: Could not parse 'region' variable from ${TFVARS_FILE}"
  exit 1
fi

# Parse repository info from the global terraform.tfvars file
BOOTSTRAP_REPO_OWNER=$(grep -E '^\s*bootstrap_repo_owner\s*=' "$GLOBAL_TFVARS_FILE" | awk -F'"' '{print $2}')
BOOTSTRAP_REPO_NAME=$(grep -E '^\s*bootstrap_repo_name\s*=' "$GLOBAL_TFVARS_FILE" | awk -F'"' '{print $2}')
CICD_REPO_OWNER=$(grep -E '^\s*cicd_repo_owner\s*=' "$GLOBAL_TFVARS_FILE" | awk -F'"' '{print $2}')
CICD_REPO_NAME=$(grep -E '^\s*cicd_repo_name\s*=' "$GLOBAL_TFVARS_FILE" | awk -F'"' '{print $2}')

echo "====================================================="
echo " Bootstrapping Environment : ${ENVIRONMENT}"
echo " Target Project ID         : ${PROJECT_ID}"
echo " Target Project Number     : ${PROJECT_NUMBER}"
echo " Pipeline ID               : ${PIPELINE_ID}"
echo "====================================================="
echo ""
echo "====================================================="
echo " ACTION REQUIRED: Connect Git Repositories"
echo "====================================================="
echo "Please visit the following URL to connect the required git repositories:"
echo "https://console.cloud.google.com/cloud-build/triggers;region=${REGION}/connect?project=${PROJECT_NUMBER}"
echo ""
echo "Required Repositories:"
echo " - ${BOOTSTRAP_REPO_OWNER}/${BOOTSTRAP_REPO_NAME}"
echo " - ${CICD_REPO_OWNER}/${CICD_REPO_NAME}"
echo "====================================================="
echo ""

read -p "Press Enter to continue or Ctrl+C to abort..."

cd "$ENV_DIR"

echo "Temporarily disabling the GCS backend..."
mv backend.tf backend.tf.bak

echo "Initializing Terraform locally..."
terraform init

echo "Planning configuration for bootstrap resources..."
terraform plan -var-file=../terraform.tfvars -var-file=terraform.tfvars

read -p "Do you want to apply these changes? Press 'y' to continue: " CONTINUE_APPLY
if [ "$CONTINUE_APPLY" != "y" ] && [ "$CONTINUE_APPLY" != "Y" ]; then
  echo "Aborting... Restoring GCS backend configuration."
  mv backend.tf.bak backend.tf
  exit 1
fi

echo "Applying configuration to create bootstrap resources..."
terraform apply -var-file=../terraform.tfvars -var-file=terraform.tfvars -auto-approve

echo "Restoring GCS backend configuration..."
mv backend.tf.bak backend.tf

echo "Migrating state to GCS..."
# -force-copy automatically answers 'yes' to the migration prompt
terraform init -migrate-state -backend-config="bucket=${PROJECT_ID}-tfstate" -backend-config="prefix=${PIPELINE_ID}/${ENVIRONMENT}" -force-copy

echo "Cleaning up local state..."
rm -f terraform.tfstate terraform.tfstate.backup

echo "Bootstrap complete for ${ENVIRONMENT}!"