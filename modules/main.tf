# Copyright 2026 Czeslaw Szubert

/**
 * # GCP Project Bootstrap Module
 * 
 * This module automates the initial setup of a Google Cloud project for CI/CD.
 * It enables required APIs, creates a dedicated Cloud Build Service Account with 
 * least-privilege IAM roles, sets up GCS buckets for Terraform state and logs, 
 * and configures a GitHub-connected Cloud Build trigger.
 */

# Define local variables for resource naming and configuration.
# Sanitized variables ensure that resource names comply with GCP naming conventions 
# by replacing underscores with hyphens.
locals {
  sanitized_platform_id         = substr(replace(var.platform_id, "_", "-"), 0, 15)
  sanitized_env                 = substr(replace(var.env, "_", "-"), 0, 4)
  bootstrap_pipeline_id         = "${local.sanitized_platform_id}-bstr"
  cicd_pipeline_id              = "${local.sanitized_platform_id}-cicd"
}


### BEGIN ENABLING APIS
# Enable Google Cloud APIs required to setup and run CloudBuild in the project.

locals {
  project_apis = [
    # Cloud Build API: To run Cloud Build Pipelines and manage triggers. (Not enabled by default)
    "cloudbuild.googleapis.com",
    # Cloud Resource Manager API: To manage project-level IAM permissions. (Not enabled by default)
    "cloudresourcemanager.googleapis.com",
    # Identity and Access Management (IAM) API: To create and manage Service Accounts. (Not enabled by default)
    "iam.googleapis.com",
    # Artifact Registry API: For creating and uploading Docker images during builds. (Not enabled by default)
    "artifactregistry.googleapis.com",
    # Cloud Storage API: To manage GCS buckets for tfstate and logs. (Enabled by default)
    "storage.googleapis.com",
    # Cloud Logging API: To allow Cloud Build and other services to write logs. (Enabled by default)
    "logging.googleapis.com",
    # Service Usage API: To enable and manage other Google Cloud APIs. (Enabled by default)
    "serviceusage.googleapis.com"
  ]
}

resource "google_project_service" "project_apis" {
  for_each           = toset(local.project_apis)
  project            = var.project
  service            = each.value

  # Prevent APIs from being disabled when running terraform destroy,
  # which would brick the project.
  disable_on_destroy = false
}
### END ENABLING APIS


### BEGIN IAM SETUP
# Create a dedicated Service Account (SA) to execute CloudBuild within the project.

# Create a dedicated service account for Cloud Build
resource "google_service_account" "cloud_build_sa" {
  # Servcie Account name limitations:
  #   Length: 6–30 characters.
  #   Characters: Lowercase letters, numbers, and hyphens (-).
  account_id   = "${local.sanitized_platform_id}-${local.sanitized_env}-cbld"
  display_name = "Service Account for Cloud Build"
  project      = var.project

  depends_on = [google_project_service.project_apis]
}

locals {
  cloudbuild_base_roles = [
    # Required to create and manage GCS buckets for Terraform state and Cloud Build logs
    "roles/storage.admin",
    # Required for Cloud Build to write its execution logs to Cloud Logging
    "roles/logging.logWriter",
    # Required to push and manage Docker images in Artifact Registry during application builds
    "roles/artifactregistry.writer",
    # Required to manage IAM permissions and role bindings at the project level
    "roles/resourcemanager.projectIamAdmin",
    # Required to create and manage dedicated Service Accounts
    "roles/iam.serviceAccountAdmin",
    # Required to enable and manage Google Cloud APIs
    "roles/serviceusage.serviceUsageAdmin",
    # Required to create, update, and manage Cloud Build triggers
    "roles/cloudbuild.builds.editor",
    # Required for the SA to act as itself when creating/updating triggers (grants iam.serviceAccounts.actAs)
    "roles/iam.serviceAccountUser"
  ]
}

# Grant the CloudBuild SA the necessary permissions to run CloudBuild IaC.
resource "google_project_iam_member" "cloud_build_base_roles" {
  for_each = toset(local.cloudbuild_base_roles)
  project = var.project
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}
### END IAM SETUP


### BEGIN STORAGE SETUP
# Create Google Cloud Storage buckets for Terraform state and Cloud Build logs.

# Create a Google Cloud Storage bucket to store Terraform state files.
resource "google_storage_bucket" "tfstate" {
  name     = "${var.project}-tfstate"
  location = var.region
  project  = var.project
  # Don't allow Terraform to delete the bucket and its contents to prevent losing state files.
  force_destroy = false

  versioning {
    enabled = true
  }

  # Delete noncurrent objects that have 31+ newer versions
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      with_state         = "ARCHIVED"
      num_newer_versions = 31
    }
  }

  # Delete objects 31+ days since they were created
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 31
    }
  }
}

# Create a Google Cloud Storage bucket to store Cloud Build logs.
resource "google_storage_bucket" "cloudbuild_logs" {
  name     = "${var.project}-cloudbuild-logs"
  location = var.region
  project  = var.project
  # Don't allow Terraform to delete the bucket and its contents to prevent losing logs.
  force_destroy = false

  # Delete objects 31+ days since they were created
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 31
    }
  }
}
### END STORAGE SETUP


### BEGIN CLOUD BUILD TRIGGER SETUP
# Create Cloud Build triggers for Platform Bootstrap and Platform CICD pipelines.

# Introduce a delay to allow IAM propagation for the newly created service account.
# This prevents a 403 "The caller does not have permission" error when creating the trigger.
resource "time_sleep" "wait_for_iam_propagation" {
  create_duration = "60s"

  # The sleep will re-run only if the service account or these IAM roles change
  triggers = {
    service_account = google_service_account.cloud_build_sa.id
    base_roles      = join(",", local.cloudbuild_base_roles)
  }

  depends_on = [
    google_project_iam_member.cloud_build_base_roles,
    google_project_service.project_apis
  ]
}

module "bootstrap_trigger" {
  source = "./cloudbuild_trigger"

  project            = var.project
  location           = var.region
  name               = "${local.bootstrap_pipeline_id}-${local.sanitized_env}-trigger"
  description        = "Cloud Build trigger to deploy Pipeline: ${local.bootstrap_pipeline_id} to Environment: ${var.env}"
  repo_owner         = var.bootstrap_repo_owner
  repo_name          = var.bootstrap_repo_name
  branch             = var.env
  service_account_id = google_service_account.cloud_build_sa.id
  
  substitutions = {
    _TF_ACTION       = "apply"
    _PROJECT_ID      = var.project
    _PIPELINE_ID     = local.bootstrap_pipeline_id
    _TERRAFORM_IMAGE = var.terraform_image
  }

  depends_on = [time_sleep.wait_for_iam_propagation]
}

module "cicd_trigger" {
  source = "./cloudbuild_trigger"

  project            = var.project
  location           = var.region
  name               = "${local.cicd_pipeline_id}-${local.sanitized_env}-trigger"
  description        = "Cloud Build trigger to deploy Pipeline: ${local.cicd_pipeline_id} to Environment: ${var.env}"
  repo_owner         = var.cicd_repo_owner
  repo_name          = var.cicd_repo_name
  branch             = var.env
  service_account_id = google_service_account.cloud_build_sa.id
  
  substitutions = {
    _TF_ACTION       = "apply"
    _PROJECT_ID      = var.project
    _PIPELINE_ID     = local.cicd_pipeline_id
    _TERRAFORM_IMAGE = var.terraform_image
  }

  depends_on = [time_sleep.wait_for_iam_propagation]
}
### END CLOUD BUILD TRIGGER SETUP