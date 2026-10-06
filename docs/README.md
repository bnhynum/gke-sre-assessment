# Documentation Index

This directory contains the supporting documentation for the GKE SRE assessment implementation.

## Documents

| Document | Purpose |
|---|---|
| [`architecture.md`](architecture.md) | Architecture diagram showing the implemented two-region GKE environment, networking, workloads, observability pipeline, Terraform management boundary, and documented production evolution. |
| [`setup.md`](setup.md) | Step-by-step implementation guide covering local tooling, GCP authentication, networking, GKE clusters, Kubernetes workloads, endpoints, Cloud Logging, BigQuery, and Terraform. |
| [`design-decisions.md`](design-decisions.md) | Engineering decisions, rationale, trade-offs, assessment constraints, and production evolution recommendations. |
| [`troubleshooting.md`](troubleshooting.md) | Real implementation issues, diagnosis, resolution steps, validation evidence, and recommended troubleshooting scenario for the assessment. |

## Recommended Reading Order

For a reviewer evaluating the assessment, the suggested order is:

1. [`../README.md`](../README.md) for the overall project summary.
2. [`architecture.md`](architecture.md) for the system view.
3. [`design-decisions.md`](design-decisions.md) for the reasoning behind the implementation.
4. [`setup.md`](setup.md) for the reproducible implementation sequence.
5. [`troubleshooting.md`](troubleshooting.md) for operational problem-solving evidence.

## Architecture Summary

The implemented assessment environment includes:

```text
sre-assessment-vpc
|
|-- gke-primary / us-central1
|   |-- App A
|   |-- App B
|   `-- primary public application endpoints
|
`-- gke-secondary / us-east1
    |-- App A
    `-- App B

GKE workloads
    |
    v
Cloud Logging
    |
    v
Log Router
    |
    v
BigQuery: gke_observability
```

Terraform represents the custom VPC, regional subnets, two GKE clusters, BigQuery dataset, and Logging sink. Kubernetes manifests separately represent the in-cluster application workloads, autoscaling, and primary-specific Services.

## Documentation Boundaries

The documentation intentionally distinguishes between:

### Implemented Assessment Infrastructure

- Custom VPC and dedicated regional GKE subnets
- Two GKE Standard clusters
- VPC-native Pod and Service address ranges
- App A and App B replicated across the clusters
- Health probes and Horizontal Pod Autoscaling
- Primary-cluster public application endpoints
- Cloud Logging
- Cloud Logging to BigQuery export
- BigQuery log analysis
- Terraform-managed GCP infrastructure

### Documented Production Evolution

- Cloud DNS
- Global external HTTPS load balancing
- Multi-cluster ingress/services
- Cloud Armor
- Private GKE nodes and Cloud NAT
- Service mesh and mTLS
- Secret Manager integration
- Distributed tracing and profiling
- Multi-zone worker placement
- Production dashboarding and structured application telemetry

Features in the production-evolution section are architectural recommendations and are not represented as completed assessment infrastructure unless explicitly documented otherwise.

## Related Project Documentation

### Terraform

See:

```text
../terraform/README.md
```

for:

- Terraform prerequisites
- resource imports
- state inspection
- validation and planning
- ADC authentication notes
- zero-drift verification

### Kubernetes

See:

```text
../kubernetes/README.md
```

for:

- primary and secondary apply commands
- server-side dry-run validation
- Kubernetes context safeguards
- rollout checks
- HPA verification
- primary-only Service handling

### BigQuery Queries

See:

```text
../queries/README.md
../queries/observability.sql
```

for:

- validated BigQuery queries
- cross-cluster application activity analysis
- request/log volume time series
- container and Pod dimensions
- the important stderr / ERROR-severity interpretation note

## Assessment Evidence Checklist

Useful evidence to collect with these documents includes:

- [ ] Architecture diagram rendered from `architecture.md`
- [ ] Primary App A endpoint screenshot
- [ ] Primary App B endpoint screenshot
- [ ] Primary cluster Pod output
- [ ] Secondary cluster Pod output
- [ ] HPA status for both applications
- [ ] GKE cluster listing
- [ ] Cloud Logging query output
- [ ] BigQuery dataset and table listing
- [ ] BigQuery query result screenshots
- [ ] Terraform validation output
- [ ] Terraform state listing
- [ ] Final Terraform plan showing no changes
- [ ] Troubleshooting evidence for the selected scenario
- [ ] Grafana screenshot/export if available, or documented environment limitation if skipped

## Key Validation Milestones

The implementation process verified the following operational milestones:

```text
GCP authentication
    -> custom VPC networking
    -> primary GKE cluster
    -> kubectl access
    -> two multi-pod applications
    -> health probes and HPA
    -> accessible primary endpoints
    -> secondary GKE cluster
    -> mirrored workloads
    -> Cloud Logging
    -> BigQuery log export
    -> working SQL analysis
    -> Terraform imports
    -> zero-drift Terraform plan
```

## Troubleshooting Evidence

The troubleshooting document includes several issues encountered during implementation. The recommended primary scenario is the Terraform Application Default Credentials issue because it has a clear:

```text
Symptom -> Diagnosis -> Resolution -> Validation
```

story ending with successful Terraform imports and a no-change plan.

Other documented scenarios include:

- missing GKE kubectl authentication plugin
- BigQuery dataset-level IAM CLI allowlisting limitation
- minimal `hello-app` image without `wget`
- Kubernetes YAML parsing/formatting issue
- misleading ERROR severity for successful sample-application requests
- pre-existing Logging sink conflict

## Repository Context

This documentation directory is part of:

```text
gke-sre-assessment/
|
|-- README.md
|-- terraform/
|-- kubernetes/
|-- queries/
`-- docs/
```

The root [`README.md`](../README.md) is the main entry point for the complete assessment submission.
