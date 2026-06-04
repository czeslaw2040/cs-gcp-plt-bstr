# Copyright 2026 Czeslaw Szubert


variable "project" {
  description = "Target project to deploy to."
  type        = string
}

variable "region" {
  description = "The Google Cloud region."
  type        = string
}

variable "platform_id" {
  description = "Unique identifier for the platform."
  type        = string
}

variable "bootstrap_repo_owner" {
  description = "The owner of the bootstrap GitHub repository."
  type        = string
}

variable "bootstrap_repo_name" {
  description = "The name of the bootstrap GitHub repository."
  type        = string
}

variable "cicd_repo_owner" {
  description = "The owner of the App CICD GitHub repository."
  type        = string
}

variable "cicd_repo_name" {
  description = "The name of the App CICD GitHub repository."
  type        = string
}

variable "terraform_image" {
  description = "Docker image and version used to execute Terraform steps in the Cloud Build pipeline."
  type        = string
}