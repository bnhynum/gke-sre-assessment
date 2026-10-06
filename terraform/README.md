# Terraform - GKE SRE Assessment

This directory contains the Terraform configuration for the GCP infrastructure used in the GKE SRE assessment.

The infrastructure was first validated manually, then represented in Terraform and imported into Terraform state. The final `terraform plan` reported no differences between configuration, state, and the live GCP resources.

## Managed Infrastructure

Terraform manages the following assessment resources:

- Custom VPC: `sre-assessment-vpc`
- Primary subnet: `gke-primary-subnet` in `us-central1`
- Secondary subnet: `gke-secondary-subnet` in `us-east1`
- Primary GKE cluster: `gke-primary`
- Secondary GKE cluster: `gke-secondary`
- BigQuery dataset: `gke_observability`
- Cloud Logging sink: `gke-logs-to-bigquery`

## Files

```text
terraform/
|-- README.md
|-- versions.tf
|-- provider.tf
|-- variables.tf
|-- network.tf
|-- gke.tf
`-- observability.tf
```

### `versions.tf`

Defines the Terraform version requirement and the HashiCorp Google provider.

### `provider.tf`

Configures the Google provider for the assessment GCP project.

### `variables.tf`

Defines shared configuration values such as:

- GCP project ID
- Primary region
- Secondary region

### `network.tf`

Defines:

- `sre-assessment-vpc`
- `gke-primary-subnet`
- `gke-secondary-subnet`
- Primary and secondary Pod alias-IP ranges
- Primary and secondary Service alias-IP ranges

### `gke.tf`

Defines both GKE Standard clusters, including:

- Regional placement
- Explicit node locations
- Regular release channel
- VPC-native IP allocation
- Workload Identity
- System and workload logging
- System monitoring
- `e2-standard-2` node configuration
- Node autoscaling from 1 to 3 nodes

### `observability.tf`

Defines:

- BigQuery dataset `gke_observability`
- Logging project sink `gke-logs-to-bigquery`
- Kubernetes container log filter: `resource.type=k8s_container`

## Prerequisites

Required local tools:

```text
Terraform
Google Cloud CLI
```

The Google provider uses Application Default Credentials for local authentication.

Authenticate the Google Cloud CLI as needed, then configure ADC:

```powershell
gcloud auth login
gcloud auth application-default login
```

Verify the active project separately before performing infrastructure operations:

```powershell
gcloud config get-value project
```

Expected assessment project:

```text
project-19ae3503-8d3c-48b5-9d8
```

## Standard Validation Workflow

From this directory:

```powershell
terraform init
terraform fmt
terraform validate
terraform plan
```

Expected validation result:

```text
Success! The configuration is valid.
```

After the existing resources were imported and reconciled, the final plan returned:

```text
No changes. Your infrastructure matches the configuration.
```

This is the desired steady state.

## Existing Resource Import Workflow

These commands document how the already-created assessment resources were brought under Terraform management.

### VPC

```powershell
terraform import google_compute_network.sre_vpc projects/project-19ae3503-8d3c-48b5-9d8/global/networks/sre-assessment-vpc
```

### Primary subnet

```powershell
terraform import google_compute_subnetwork.primary projects/project-19ae3503-8d3c-48b5-9d8/regions/us-central1/subnetworks/gke-primary-subnet
```

### Secondary subnet

```powershell
terraform import google_compute_subnetwork.secondary projects/project-19ae3503-8d3c-48b5-9d8/regions/us-east1/subnetworks/gke-secondary-subnet
```

### Primary GKE cluster

```powershell
terraform import google_container_cluster.primary projects/project-19ae3503-8d3c-48b5-9d8/locations/us-central1/clusters/gke-primary
```

### Secondary GKE cluster

```powershell
terraform import google_container_cluster.secondary projects/project-19ae3503-8d3c-48b5-9d8/locations/us-east1/clusters/gke-secondary
```

### BigQuery dataset

```powershell
terraform import google_bigquery_dataset.gke_observability projects/project-19ae3503-8d3c-48b5-9d8/datasets/gke_observability
```

### Logging sink

```powershell
terraform import google_logging_project_sink.gke_logs_to_bigquery projects/project-19ae3503-8d3c-48b5-9d8/sinks/gke-logs-to-bigquery
```

## Inspecting Terraform State

List resources managed in state:

```powershell
terraform state list
```

Expected resources include:

```text
google_bigquery_dataset.gke_observability
google_compute_network.sre_vpc
google_compute_subnetwork.primary
google_compute_subnetwork.secondary
google_container_cluster.primary
google_container_cluster.secondary
google_logging_project_sink.gke_logs_to_bigquery
```

## Network Addressing

| Cluster | Region | Node CIDR | Pod CIDR | Service CIDR |
|---|---|---|---|---|
| Primary | `us-central1` | `10.10.0.0/20` | `10.20.0.0/16` | `10.30.0.0/20` |
| Secondary | `us-east1` | `10.40.0.0/20` | `10.50.0.0/16` | `10.60.0.0/20` |

## Cluster Configuration

Both clusters follow the same basic operational pattern:

```text
Mode:             GKE Standard
Release channel:  Regular
Machine type:     e2-standard-2
Node autoscaling: min 1 / max 3
Workload Identity enabled
VPC-native networking enabled
Cloud Logging enabled for system/workload logs
Cloud Monitoring enabled for system components
```

Assessment node locations:

```text
gke-primary   -> us-central1-a
gke-secondary -> us-east1-b
```

The single-zone node placement keeps the assessment implementation small. A production regional design can distribute worker nodes across multiple zones for stronger intra-region availability.

## Observability Infrastructure

The Terraform-managed logging path is:

```text
GKE workloads
    |
    v
Cloud Logging
    |
    v
gke-logs-to-bigquery
    |
    v
BigQuery dataset: gke_observability
```

The sink filter is:

```text
resource.type=k8s_container
```

The BigQuery export was validated by the creation of log tables and successful SQL queries against exported GKE container records.

## Applying Changes Safely

Always inspect the plan first:

```powershell
terraform plan
```

Do not run `terraform apply` merely because Terraform is installed or initialized.

Only run an apply when:

1. The planned change is intentional.
2. The correct GCP project has been verified.
3. No unexpected resource replacement or destruction is present.
4. The impact of the change has been reviewed.

If the plan contains an unexpected replacement such as:

```text
-/+ destroy and then create replacement
```

stop and reconcile the configuration rather than applying it.

For the completed assessment configuration, the desired plan is:

```text
No changes. Your infrastructure matches the configuration.
```

## Authentication Troubleshooting

An important distinction encountered during implementation was the difference between normal gcloud authentication and Application Default Credentials.

Normal CLI authentication:

```powershell
gcloud auth login
```

Terraform Google provider local authentication:

```powershell
gcloud auth application-default login
```

The Terraform import initially failed because ADC had not yet been configured. After ADC was established, Terraform successfully imported the existing resources.

Do not commit credential files, access tokens, or other secrets to the repository.

## BigQuery / Logging IAM Note

During implementation, an attempted dataset-level IAM binding using the `bq` CLI returned:

```text
This feature requires allowlisting.
```

A project-level IAM binding was used for the Cloud Logging sink writer identity in the assessment environment. After permission was available, the Logging sink successfully exported GKE container logs into the BigQuery dataset.

For a production environment, use the narrowest IAM scope supported by the environment and organizational policy.

## What Terraform Does Not Manage Here

The application workloads are kept separately as Kubernetes manifests under:

```text
../kubernetes/
```

That separation keeps responsibilities clear:

```text
Terraform
  -> GCP infrastructure

Kubernetes YAML
  -> application Deployments
  -> HPAs
  -> Services
```

BigQuery analysis queries are stored separately under:

```text
../queries/
```

## Useful Verification Commands

Check GKE clusters:

```powershell
gcloud container clusters list
```

Check VPC/subnets:

```powershell
gcloud compute networks list
gcloud compute networks subnets list
```

Check BigQuery dataset:

```powershell
bq ls
bq ls project-19ae3503-8d3c-48b5-9d8:gke_observability
```

Check Logging sink:

```powershell
gcloud logging sinks describe gke-logs-to-bigquery
```

Check Terraform drift:

```powershell
terraform plan
```

## Assessment Evidence

Useful Terraform evidence for the final submission includes:

- `terraform validate` showing valid configuration
- `terraform state list` showing managed infrastructure
- final `terraform plan` showing no changes
- Terraform source files in this directory
- documentation of the ADC authentication issue and resolution

## Operator Safety

- Verify the GCP project before every infrastructure operation.
- Review `terraform plan` before every apply.
- Never commit Terraform credentials or access tokens.
- Treat Terraform state as potentially sensitive infrastructure metadata.
- Avoid manual changes to Terraform-managed resources unless the resulting drift will be intentionally reconciled.
