# Terraform - GKE SRE Assessment

This directory contains the Terraform configuration for the Google Cloud infrastructure used in the GKE SRE Assessment.

The assessment infrastructure was initially validated manually and subsequently imported into Terraform state to provide reproducible Infrastructure as Code (IaC). After configuration reconciliation, the final Terraform plan reported no drift between the configuration, Terraform state, and deployed GCP resources.

---

## Overview

This Terraform implementation provisions and manages the core infrastructure required for:

- Multi-region GKE deployment
- Cross-region application hosting
- VPC-native Kubernetes networking
- Centralized logging and observability
- BigQuery-based log analytics
- Workload Identity integration
- IAM architecture for operational personas
- Terraform-managed infrastructure lifecycle

The deployed architecture supports:

```text
Primary Region   : us-central1
Secondary Region : us-east1

Infrastructure Components:
- Custom VPC
- Regional GKE clusters
- Alias-IP networking
- Cloud Logging
- BigQuery observability
- IAM architecture
- Workload Identity
- Managed Prometheus
```

---

# Managed Infrastructure

Terraform manages the following assessment resources.

## Networking

- Custom VPC: `sre-assessment-vpc`
- Primary subnet: `gke-primary-subnet`
- Secondary subnet: `gke-secondary-subnet`
- Primary Pod CIDR allocation
- Primary Service CIDR allocation
- Secondary Pod CIDR allocation
- Secondary Service CIDR allocation
- Load-balancer subnet reservation
- Operations / Monitoring subnet reservation

## GKE

- Primary cluster: `gke-primary`
- Secondary cluster: `gke-secondary`
- VPC-native networking
- Workload Identity
- Cloud Logging integration
- Cloud Monitoring integration
- Managed Prometheus
- Node autoscaling configuration

## Observability

- BigQuery dataset: `gke_observability`
- Cloud Logging sink: `gke-logs-to-bigquery`
- Kubernetes container log export configuration

## IAM

Terraform also documents and manages the assessment IAM model, including:

- Developer persona access
- Operations persona access
- SRE persona access
- CI/CD persona access
- Conditional IAM bindings
- Separation of human identities from automation identities
- Workload-identity-based authentication strategy

---

# Files

```text
terraform/
|-- README.md
|-- versions.tf
|-- provider.tf
|-- variables.tf
|-- network.tf
|-- gke.tf
|-- observability.tf
`-- iam.tf
```

---

## versions.tf

Defines:

- Terraform version requirements
- Google provider requirements

---

## provider.tf

Configures:

- Google Cloud provider
- Project configuration
- Authentication source

---

## variables.tf

Defines reusable variables including:

- Project ID
- Primary region
- Secondary region

---

## network.tf

Creates and manages:

```text
sre-assessment-vpc

├── gke-primary-subnet
├── gke-secondary-subnet
├── lb-subnet
└── ops-monitoring-subnet
```

Also defines:

- Primary Pod CIDR range
- Primary Service CIDR range
- Secondary Pod CIDR range
- Secondary Service CIDR range

---

## gke.tf

Defines both GKE Standard clusters.

Key configuration includes:

- Regional deployment
- Explicit node locations
- Regular release channel
- Workload Identity
- Managed Prometheus
- Cloud Logging
- Cloud Monitoring
- VPC-native networking
- Alias IP ranges
- Node autoscaling
- e2-standard-2 worker nodes

Cluster configuration:

```text
Mode:               GKE Standard
Release Channel:    Regular
Machine Type:       e2-standard-2

Node Autoscaling:
  Min Nodes: 1
  Max Nodes: 3

Logging:
  System Logs
  Workload Logs

Monitoring:
  System Monitoring
  Managed Prometheus

Security:
  Workload Identity Enabled
```

---

## observability.tf

Defines:

### BigQuery

```text
Dataset:
gke_observability
```

### Cloud Logging Sink

```text
gke-logs-to-bigquery
```

### Log Export Filter

```text
resource.type="k8s_container"
```

This configuration exports Kubernetes container logs into BigQuery for long-term storage and analysis.

---

## iam.tf

Defines the assessment IAM architecture.

Personas include:

| Persona | Responsibility |
|----------|----------|
| Developer | Application deployment and troubleshooting |
| Operations | Platform operations and support |
| SRE | Reliability, monitoring, logging, observability |
| CI/CD | Automated deployments |

The IAM model follows:

- Least privilege principles
- Group-based access
- Human/automation separation
- Conditional role assignments
- Keyless authentication preference

---

# Prerequisites

Install:

```text
Terraform
Google Cloud CLI
```

Authentication uses Application Default Credentials (ADC).

Login to Google Cloud:

```powershell
gcloud auth login
```

Configure ADC:

```powershell
gcloud auth application-default login
```

Verify active project:

```powershell
gcloud config get-value project
```

Expected project:

```text
project-19ae3503-8d3c-48b5-9d8
```

---

# Standard Validation Workflow

Run from this directory:

```powershell
terraform init

terraform fmt

terraform validate

terraform plan
```

Expected output:

```text
Success! The configuration is valid.
```

Desired final state:

```text
No changes. Your infrastructure matches the configuration.
```

---

# Import Workflow

The assessment environment was created before Terraform management was introduced.

Resources were imported into state and reconciled.

## VPC

```powershell
terraform import google_compute_network.sre_vpc projects/project-19ae3503-8d3c-48b5-9d8/global/networks/sre-assessment-vpc
```

## Primary Subnet

```powershell
terraform import google_compute_subnetwork.primary projects/project-19ae3503-8d3c-48b5-9d8/regions/us-central1/subnetworks/gke-primary-subnet
```

## Secondary Subnet

```powershell
terraform import google_compute_subnetwork.secondary projects/project-19ae3503-8d3c-48b5-9d8/regions/us-east1/subnetworks/gke-secondary-subnet
```

## Primary GKE Cluster

```powershell
terraform import google_container_cluster.primary projects/project-19ae3503-8d3c-48b5-9d8/locations/us-central1/clusters/gke-primary
```

## Secondary GKE Cluster

```powershell
terraform import google_container_cluster.secondary projects/project-19ae3503-8d3c-48b5-9d8/locations/us-east1/clusters/gke-secondary
```

## BigQuery Dataset

```powershell
terraform import google_bigquery_dataset.gke_observability projects/project-19ae3503-8d3c-48b5-9d8/datasets/gke_observability
```

## Logging Sink

```powershell
terraform import google_logging_project_sink.gke_logs_to_bigquery projects/project-19ae3503-8d3c-48b5-9d8/sinks/gke-logs-to-bigquery
```

---

# Network Addressing

| Cluster | Region | Node CIDR | Pod CIDR | Service CIDR |
|----------|----------|----------|----------|----------|
| Primary | us-central1 | 10.10.0.0/20 | 10.20.0.0/16 | 10.30.0.0/20 |
| Secondary | us-east1 | 10.40.0.0/20 | 10.50.0.0/16 | 10.60.0.0/20 |

Both clusters use GKE VPC-native alias IP networking.

---

# Cluster Placement

```text
gke-primary
└── us-central1-a

gke-secondary
└── us-east1-b
```

The assessment uses single-zone worker-node placement to keep infrastructure costs and complexity manageable.

Production deployments would typically distribute worker nodes across multiple zones within each region.

---

# Observability Architecture

Terraform manages the infrastructure supporting the following logging path:

```text
Applications
     |
     v
GKE Workloads
     |
     v
Cloud Logging
     |
     v
gke-logs-to-bigquery
     |
     v
BigQuery Dataset
(gke_observability)
     |
     v
Grafana / SQL Analysis
```

The export was validated through:

- BigQuery table creation
- Successful log ingestion
- BigQuery query execution
- Grafana dashboard integration

---

# Authentication Troubleshooting

An implementation issue encountered during the assessment involved Application Default Credentials.

CLI authentication:

```powershell
gcloud auth login
```

Terraform authentication:

```powershell
gcloud auth application-default login
```

Terraform imports initially failed because ADC had not been configured. Once ADC was established, imports completed successfully and Terraform state was reconciled.

Never commit:

- Access tokens
- Credential files
- Service account secrets
- Terraform state backups containing secrets

---

# BigQuery Logging IAM Note

During implementation, a dataset-level IAM assignment attempt returned:

```text
This feature requires allowlisting.
```

The assessment environment successfully used project-level permissions for the Cloud Logging sink writer identity.

After permissions were assigned:

- Logging export succeeded
- BigQuery tables were created
- Container logs were successfully ingested

---

# What Terraform Does Not Manage

Application deployment is managed separately:

```text
../kubernetes/
```

Responsibility separation:

```text
Terraform
  -> Infrastructure
  -> Networking
  -> GKE
  -> IAM
  -> Observability

Kubernetes YAML
  -> Deployments
  -> Services
  -> ConfigMaps
  -> Secrets
  -> HPAs
```

Observability queries are stored separately:

```text
../queries/
```

---

# Useful Verification Commands

## GKE

```powershell
gcloud container clusters list
```

## Networking

```powershell
gcloud compute networks list

gcloud compute networks subnets list
```

## BigQuery

```powershell
bq ls

bq ls project-19ae3503-8d3c-48b5-9d8:gke_observability
```

## Logging Sink

```powershell
gcloud logging sinks describe gke-logs-to-bigquery
```

## Terraform Drift

```powershell
terraform plan
```

---

# Assessment Evidence

Useful Terraform evidence includes:

- `terraform validate`
- `terraform state list`
- Final `terraform plan`
- Infrastructure source code
- Resource import documentation
- ADC troubleshooting documentation
- IAM architecture implementation
- Workload Identity configuration

---

# Operator Safety

- Verify the active GCP project before every Terraform operation.
- Review every plan before applying changes.
- Never apply unreviewed replacement operations.
- Do not store credentials in the repository.
- Treat Terraform state as sensitive infrastructure metadata.
- Reconcile infrastructure drift intentionally.
- Expected steady state is:

```text
No changes. Your infrastructure matches the configuration.
```