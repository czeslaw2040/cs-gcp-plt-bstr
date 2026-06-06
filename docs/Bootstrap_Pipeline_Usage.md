Copyright 2026 Czeslaw Szubert

> **⚠️ DISCLAIMER: Experimental Platform**
> 
> This project is an **experimental platform** and is **not intended or ready for enterprise production workloads**. The code is provided "as-is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software. Use at your own risk.

## Table of Contents

- [Introduction](#introduction)
- [Bootstrap Pipeline Configurations](#bootstrap-pipeline-configurations)
  - [Global Platform Bootstrap Configuration](#global-platform-bootstrap-configuration)
  - [Environment Specific Configuration](#environment-specific-configuration)
  - [Overwrite Configurations](#overwrite-configurations)
- [Resources Created by the Platform Bootstrap Pipeline](#resources-created-by-the-platform-bootstrap-pipeline)
- [Setup and Usage Procedure](#setup-and-usage-procedure)
  - [Overall Platform Setup and Usage](#overall-platform-setup-and-usage)
  - [Bootstrap Pipeline Setup and Usage](#bootstrap-pipeline-setup-and-usage)
    - [Prerequisites](#prerequisites)
    - [Initial Setup Steps](#initial-setup-steps)
    - [Subsequent executions of the Bootstrap Pipeline](#subsequent-executions-of-the-bootstrap-pipeline)
    - [Manual Terraform Execution (tf.sh)](#manual-terraform-execution-tfsh)
    - [Teardown and Cleanup](#teardown-and-cleanup)
- [Future Enhancements](#future-enhancements)

# Introduction
This README provides detailed usage instructions of the **Platform Bootstrap Repository**, which is the first repository used to create the GCP Platform.  This repository is used to initialize the foundational CICD GCP projects and resources needed to execute Cloud Build pipelines. 


# Bootstrap Pipeline Configurations

## Global Platform Bootstrap Configuration
Global platform bootstrap configurations define the core identity of the platform across all environments.

| Parameter Name | Configuration Parameter | Default or Suggested Value | File Location | Detailed Description |
| :--- | :--- | :--- | :--- | :--- |
| **Platform ID** | **`platform_id`** | ex. `my-plt` | `environments/terraform.tfvars` | The base ID used by Terraform and scripts to generate pipeline IDs (`[platform_id]-bstr`, `[platform_id]-cicd`) for pipeline resource nomenclature, including generating pipeline trigger names and constructing the state path (prefix) in the GCS bucket. <br>Keep this less than 15 characters long to avoid exceeding GCP resource name limits. |
| **Bootstrap Repo Owner** | **`bootstrap_repo_owner`** | ex. `github-user` | `environments/terraform.tfvars` | The GitHub organization or user account that owns the platform bootstrap repository. Used to link the GitHub repo to the Cloud Build trigger. |
| **Bootstrap Repo Name** | **`bootstrap_repo_name`** | [Platform ID]-bstr <br>ex. `my-plt-bstr` | `environments/terraform.tfvars` | The repository name of the platform bootstrap codebase. Used to link the GitHub repo to the Cloud Build trigger. |
| **CICD Repo Owner** | **`cicd_repo_owner`** | ex. `github-user` | `environments/terraform.tfvars` | The GitHub organization or user account that owns the platform's CICD repository. |
| **CICD Repo Name** | **`cicd_repo_name`** | [Platform ID]-cicd <br>ex. `my-plt-cicd` | `environments/terraform.tfvars` | The repository name of the platform's CICD codebase. |
| **Terraform Image** | **`terraform_image`** | `hashicorp/terraform:1.15.0` | `environments/terraform.tfvars` | Docker image and version used to execute Terraform steps in the Cloud Build pipeline. Passed to the trigger as the `_TERRAFORM_IMAGE` substitution variable. |


## Environment Specific Configuration
Environment specific configurations define parameters like the target GCP project and region where the platform resources will be deployed for a particular environment.

| Parameter Name | Configuration Parameter | Default or Suggested Value | File Location | Detailed Description |
| :--- | :--- | :--- | :--- | :--- |
| **CICD Pipeline Project ID** | **`project`** | `[Platform ID]-[environment]-cicd` | `environments/<environment>/terraform.tfvars` | The Google Cloud Project ID where the platform resources (CI/CD pipelines, state buckets, Cloud Build service account) will be deployed. This is also parsed by bootstrap scripts to set the active `gcloud` project context and construct the GCS state bucket name. |
| **Region** | **`region`** | ex. `us-central1` | `environments/<environment>/terraform.tfvars` | The Google Cloud region where resources (e.g., Cloud Storage buckets, Cloud Build triggers) will be created. It is also used during the initial setup script to generate the correct region-specific Cloud Console URL for connecting GitHub repositories. |

**Note:** `<environment>` is determined by the git branch. A corresponding subfolder `environments/<environment>/` must exist. 


## Overwrite Configurations
Overwrite configurations are used to bypass default safety mechanisms or modify pipeline behavior for specific operational requirements. Specifically, to enable teardown of the production environment, when needed by adding an additional acknowledgement to avoid accidental execution.

| Parameter Name | Configuration Parameter | File Location | Detailed Description |
| :--- | :--- | :--- | :--- |
| **Allow Prod Destroy** | **`ALLOW_PROD_DESTROY`** | `cloudbuild.yaml`<br>`scripts/tf.sh` | A commented-out internal safety flag. By default, the CICD pipeline and local scripts will reject any `destroy` action on a `prod` environment. To perform a production teardown, this variable must be explicitly uncommented and set to `"true"`. |


# Resources Created by the Platform Bootstrap Pipeline
The resources deployed by the Platform Bootstrap pipeline are shared by all CICD pipelines including Platform Bootstrap, Platform CICD and APP build and deploy pipelines. These resources are deployed to the CICD pipeline project(s).

**Note:** The usual convention for resource names in the platform is `[Pipeline ID]-[environment]-[resource type]`.

| Resource | Identifier / Path | Description | Resource Labels |
|---|---|---|---|
| **Cloud Build Service Account** | `[Platform ID]-[environment]-cbld@[CICD Project ID].iam.gserviceaccount.com` | Used to execute the Platform Bootstrap and CICD Cloud Build pipelines.* | *None* |
| **TF state file bucket** | `[CICD Project ID]-tfstate` | Stores all platform terraform state files.<br> All TF state files will be stored in the `[Pipeline ID]/<environment>` prefix. | *None* |
| **Cloud Build logs bucket** | `[CICD Project ID]-cloudbuild-logs` | Stores all platform Cloud Build logs. | *None* |
| **Platform Bootstrap Pipeline Trigger** | `[Pipeline ID]-[environment]-trigger` | | *None* |
| **Platform CICD Pipeline Trigger** | `[Pipeline ID]-[environment]-trigger` | | *None* |

*Granting new permissions to the Platform Service Account will require execution by user with appropriate access.


# Setup and Usage Procedure

## Overall Platform Setup and Usage
For each environment:
1. Run **Platform Bootstrap pipeline** to initialize the CICD GCP project. This also creates the platform bootstrap pipeline.
1. Run **Platform CICD pipeline** to create App build and deploy pipelines and to setup target App GCP projects.  This pipeline will need to be executed again to create any new application pipelines or to update APIs or Cloud Build Service Account permissions (escalation roles) for existing application pipelines.
1. For each App included in the target environment, run individual **App build and deploy pipelines** to build, deploy and update each application.


## Bootstrap Pipeline Setup and Usage

### Prerequisites

1. The **CICD Pipeline GCP project** must exist and the following APIs must be enabled to run the bootstrap script:
    * Cloud Resource Manager API
    * Service Usage API
    * Identity and Access Management API
1. The user executing the bootstrap script must have the required privileges:
    * The **GitHub repositories:** You must have **Repository Admin** or **Organization Owner** access to the targeted GitHub repositories (**Platform Bootstrap Repo** and **Platform CICD Repo**). This is required so you can install the "Google Cloud Build" GitHub app and grant it repository access.
    * The **CICD GCP Pipeline project:** Adhering strictly to the principle of least privilege, the following combination of roles is required:
        * *For the manual GitHub Connection step:*
            * **Cloud Build Connection Admin** (`roles/cloudbuild.connectionAdmin`)
        * *For the script and Terraform execution:*
            * **Viewer** (`roles/viewer`) or **Browser** (`roles/browser`) - to retrieve the project number via `gcloud`.
            * **Service Usage Admin** (`roles/serviceusage.serviceUsageAdmin`) - to enable required Google Cloud APIs.
            * **Service Account Admin** (`roles/iam.serviceAccountAdmin`) - to create the dedicated Cloud Build service account.
            * **Project IAM Admin** (`roles/resourcemanager.projectIamAdmin`) - to bind IAM roles to the newly created service account.
            * **Storage Admin** (`roles/storage.admin`) - to create the GCS buckets for Terraform state and logs.
            * **Cloud Build Editor** (`roles/cloudbuild.builds.editor`) - to create the Cloud Build triggers.
            * **Service Account User** (`roles/iam.serviceAccountUser`) - to attach the service account to the Cloud Build triggers.


### Initial Setup Steps

1. The **Platform Bootstrap Git repository** must be created and configured for your pipeline. Since this repository is a template, you can easily create a new repository from it:
    * **Using the GitHub UI:** Click the **Use this template** button at the top right of this repository's page, select **Create a new repository**, and name it (ex. `[Platform ID]-bstr`). Clone your newly created repository locally.
    * **Using the GitHub CLI:**
    ```bash
    gh repo create <Owner>/<Platform ID>-bstr --template github-user/my-plt-bstr --private --clone
    cd <Platform ID>-bstr
    ```
1. Repeat the above to create the **Platform CICD Git repository**; the cicd repository must exist so that the bootstrap pipeline can create a trigger for it.
1. Clone the **Platform Bootstrap Git repository** to your IDE. Make sure you are on the branch corresponding to the environment you are creating and the environment specific folder `environments/[environment]`.
1. Update global platform configurations `environments/terraform.tfvars` and environment specific configurations `environments/[environment]/terraform.tfvars` as per your target platform.
1. Execute the bootstrap script from the root of your repository, passing your target environment (e.g., `dev` or `prod`).
    ```bash
    ./scripts/bootstrap.sh dev
    ```

    - The script will automatically pause before applying the Terraform configuration. It will provide a URL for you to visit to connect your GitHub repositories to Cloud Build. Follow the provided URL. 
    - If the Cloud Build API is not yet enabled in the project, you will be asked to enable it first. 
    - Then follow the dialog to authorize GitHub, add **Google Cloud Build** to **GitHub Apps** on the repository.
    - Connect the bootstrap and cicd repositories, but exit the dialog before creating a trigger (Terraform will create the triggers for you).
    - Once connected, return to the terminal and press Enter to resume the script. 
    - The script will then automatically handle the initial local application, GCS state migration, and cleanup.
1. Platform bootstrap is now complete. You can go to your **CICD GCP Project**, check to make sure the resources have been created, and manually trigger the **Platform Bootstrap Pipeline** one more time to make sure it runs successfully. You will only need to rerun this pipeline if you change any of the terraform code or settings in this repository, which should not be required under normal platform operations - all application specific build and deployments are managed through the **Platform CICD Pipeline**.
1. Next, proceed to clone the **Platform CICD Git repository** and start adding your application pipelines.


### Subsequent executions of the Bootstrap Pipeline
The bootstrap pipeline can be executed automatically, using the created Cloud Build trigger, or by executing the `scripts/tf.sh` script manually. The pipeline needs to be executed any time the code for resources created by the bootstrap pipeline are updated, but this should not be required for normal operations of the platform after the initial execution of `scripts/bootstrap.sh` unless the terraform code or variables in this repo are updated.

To update the resources created by the bootstrap pipeline:
1. Update the corresponding IaC code in the bootstrap repository on the target branch.
1. Push the changes to github.
1. Cloud Build trigger will detect the new commit and create a new pipeline run, but will pause for a User to **Accept** the run.
1. Once the run is accepted, make sure the pipeline executed successfully.


### Manual Terraform Execution (tf.sh)
You can execute the pipeline using the `scripts/tf.sh` script.  This would be necessary when the changes include any role update to the Cloud Build Service Account and would need to be executed by a user with appropriate access.

If you need to execute Terraform commands manually after the initial bootstrap (e.g., to run `plan`, `apply`, or `destroy` locally), you can use the `tf.sh` helper script. This script automatically runs `terraform init` with the correct remote GCS backend configuration for the specified environment before executing your command.

**Usage:**
```bash
./scripts/tf.sh <environment> <terraform_command> [additional_args...]
```

**Examples:**
* Run a plan for the `dev` environment:
  ```bash
  ./scripts/tf.sh dev plan
  ```
* Apply changes to the `dev` environment:
  ```bash
  ./scripts/tf.sh dev apply
  ```
  

### Teardown and Cleanup

To tear down the resources created by this bootstrap process, it is recommended to use the Cloud Build trigger created during the initial setup, passing the destroy flag.

1. Go to the **Cloud Build > Triggers** page in the GCP Console for the target CICD project.
2. Locate the Platform Bootstrap Pipeline trigger.
3. Click **Run** and provide the following substitution variable (if not already configured):
   * `_TF_ACTION`: `destroy`
4. Monitor the build logs to ensure all resources are successfully removed.
5. **Note:** 
    * Before teardown of the resources created by the Platform Bootstrap Pipeline, make sure to first run teardown on all applications followed by teardown on the CICD Pipeline.
    * **Production Safeguard:** Destroying the `prod` environment is forbidden by default. To authorize a prod teardown, you must first modify the `cloudbuild.yaml` (or `scripts.tf`) file to uncomment the `ALLOW_PROD_DESTROY="true"` variable, commit, and merge this change before running the trigger.
    * The GCS bucket containing the Terraform state and the Cloud Build logs will not be deleted. Note: `force_destroy` property was purposely set to false - this will cause terraform destroy to fail. If needed, the buckets must be removed manually.
    * APIs will also not be disabled, because it would prevent Cloud Build from running again in this project.
