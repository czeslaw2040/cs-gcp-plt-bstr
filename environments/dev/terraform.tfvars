# Copyright 2026 Czeslaw Szubert


# This file contains environment-specific variables for this environment.
# These values supplement the global variables defined in the 
# root 'terraform.tfvars' file.

# project: The CICD Google Cloud Project ID where the Bootstrap Pipeline resources will be deployed for this Environment.
project = "my-plt-dev-cicd"

# region: The GCP region used for regional resources like GCS buckets and Cloud Build triggers.
region  = "us-central1"
