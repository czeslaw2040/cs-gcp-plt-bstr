# Copyright 2026 Czeslaw Szubert


variable "project" {
  description = "The Google Cloud project ID where resources will be deployed."
  type        = string
}

variable "location" {
  description = "The Google Cloud region where resources will be deployed."
  type        = string
}

variable "name" {
  description = "The name of the Cloud Build trigger."
  type        = string
}

variable "description" {
  description = "Description for the Cloud Build trigger."
  type        = string
}

variable "repo_owner" {
  description = "The owner of the GitHub repository."
  type        = string
}

variable "repo_name" {
  description = "The name of the GitHub repository."
  type        = string
}

variable "branch" {
  description = "The branch name to trigger the build."
  type        = string
}

variable "service_account_id" {
  description = "The ID of the Cloud Build Service Account."
  type        = string
}

variable "substitutions" {
  description = "A map of substitution variables for the Cloud Build trigger."
  type        = map(string)
  default     = {}
}
