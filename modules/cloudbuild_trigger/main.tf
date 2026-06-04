# Copyright 2026 Czeslaw Szubert

/**
 * # Cloud Build Trigger Submodule
 * 
 * This submodule abstracts the creation of a generic Google Cloud Build trigger.
 * It configures a GitHub-backed trigger that responds to branch pushes and 
 * requires manual approval before execution.
 */

resource "google_cloudbuild_trigger" "trigger" {
  name        = var.name
  project     = var.project
  location    = var.location
  description = var.description

  github {
    owner = var.repo_owner
    name  = var.repo_name
    push {
      branch = "^${var.branch}$"
    }
  }

  filename        = "cloudbuild.yaml"
  service_account = var.service_account_id
  substitutions   = var.substitutions

  approval_config {
    approval_required = true
  }
}