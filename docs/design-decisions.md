# Design Decisions

This document records the key engineering decisions made for the GKE SRE assessment, including the assessment-focused implementation choices, their trade-offs, and the production evolution path.

## Decision Principles

The implementation prioritized:

1. A working, testable GKE environment.
2. Reproducible infrastructure and workload configuration.
3. Clear separation between assessment implementation and production architecture.
4. Observable workloads with verified log data.
5. Cost and complexity control where the assessment allowed optional or unavailable features to be skipped.
6. Explicit validation before expanding the architecture.

## 1. Use GKE Standard Rather Than Autopilot

### Decision

Use **GKE Standard** for both clusters.

### Rationale

The assessment allowed either Standard or Autopilot. Standard was selected because the exercise benefits from showing direct control over node configuration, node autoscaling, networking, and operational behavior.

The implemented worker configuration is:

```text
Machine type:     e2-standard-2
Autoscaling:      1 to 3 nodes
Release channel:  Regular
```

### Trade-off

Standard requires more infrastructure decisions than Autopilot. For this assessment, that additional control was useful because cluster operations and infrastructure configuration are part of what is being demonstrated.

## 2. Use Two Regional GKE Clusters

### Decision

Deploy:

```text
gke-primary   -> us-central1
gke-secondary -> us-east1
```

### Rationale

The two-cluster model demonstrates workload replication across regions and provides a foundation for active/active, active/passive, DR, blue/green, or canary strategies.

### Assessment Implementation

Each regional cluster uses one explicit worker-node zone:

```text
gke-primary   -> us-central1-a
gke-secondary -> us-east1-b
```

This keeps the assessment footprint controlled while preserving the cross-region cluster design.

### Production Evolution

A production implementation should evaluate distributing worker nodes across multiple zones within each region to improve intra-region availability.

## 3. Use One Custom VPC

### Decision

Create a dedicated custom-mode network:

```text
sre-assessment-vpc
```

rather than deploying the assessment into the default auto-mode VPC.

### Rationale

A custom VPC provides explicit control over subnet placement and CIDR allocation and makes the relationship between the two GKE clusters easier to understand and reproduce.

The existing default VPC was left unchanged.

## 4. Use Dedicated Regional Subnets

### Decision

Use one dedicated subnet for each cluster.

| Cluster | Region | Subnet | Node CIDR |
|---|---|---|---|
| Primary | `us-central1` | `gke-primary-subnet` | `10.10.0.0/20` |
| Secondary | `us-east1` | `gke-secondary-subnet` | `10.40.0.0/20` |

### Rationale

This matches the assessment's cluster-segmentation model and makes regional addressing explicit.

## 5. Use VPC-Native Alias IP Ranges

### Decision

Give each cluster dedicated Pod and Service secondary ranges.

```text
Primary
  Nodes:    10.10.0.0/20
  Pods:     10.20.0.0/16
  Services: 10.30.0.0/20

Secondary
  Nodes:    10.40.0.0/20
  Pods:     10.50.0.0/16
  Services: 10.60.0.0/20
```

### Rationale

The assessment explicitly calls for VPC-native GKE networking using alias IP ranges. Separate ranges also make node, Pod, and Kubernetes Service addressing easy to identify during troubleshooting.

The implementation verified that primary Pods received `10.20.x.x` addresses and secondary Pods received `10.50.x.x` addresses.

## 6. Keep the Initial Cluster Nodes Public Rather Than Private

### Decision

Do not make private GKE nodes part of the assessment implementation.

### Rationale

Private GKE clusters were optional in the assessment. Introducing private nodes would also introduce additional egress design, such as Cloud NAT, before the core application and observability requirements were proven.

### Production Evolution

For a hardened production environment, evaluate private worker nodes, controlled egress, Cloud NAT, Private Google Access, and organization-specific firewall policy.

## 7. Use Symmetrical Workloads Across Both Clusters

### Decision

Deploy the same App A and App B workload configuration to both clusters.

### Rationale

Symmetry reduces operational differences between primary and secondary environments and supports future failover or multi-cluster routing patterns.

Both applications use:

```text
Initial replicas: 2
CPU request:      100m
CPU limit:        250m
Memory request:   64Mi
Memory limit:     128Mi
HPA minimum:      2
HPA maximum:      5
HPA CPU target:   60%
```

Both also use HTTP readiness and liveness probes.

## 8. Use Simple Stateless Sample Applications

### Decision

Use:

```text
App A -> nginx:1.27
App B -> gcr.io/google-samples/hello-app:1.0
```

### Rationale

The assessment is primarily demonstrating GKE architecture, scaling, networking, observability, and infrastructure management. Simple stateless workloads reduce unrelated application-development effort while still providing real Deployments, Services, Pods, health probes, logs, and HTTP endpoints.

## 9. Separate Common Workloads from Cluster-Specific Exposure

### Decision

Keep these resources common to both clusters:

```text
app-a.yaml -> Deployment + HPA
app-b.yaml -> Deployment + HPA
```

Keep public primary-cluster Services in:

```text
primary-services.yaml
```

### Rationale

This prevents an accidental application of public `LoadBalancer` Services to the secondary/DR cluster.

The operator must verify the current Kubernetes context before applying cluster-specific resources.

## 10. Use Primary-Only Public LoadBalancer Services for Endpoint Validation

### Decision

Expose the applications publicly on the primary cluster for the assessment endpoint proof rather than creating independent public LoadBalancers on both clusters.

### Rationale

The assessment required a working accessible application endpoint. Primary-only Services provide that evidence without creating unnecessary duplicate public infrastructure in the secondary region.

The primary App A and App B endpoints were both validated with live HTTP requests.

### Production Evolution

The intended production evolution is a single global customer-facing architecture using components such as:

```text
Cloud DNS
Global external HTTPS load balancing
multi-cluster traffic management
health-based failover
TLS termination
Cloud Armor
```

Those features are documented as production architecture rather than claimed as implemented assessment resources.

## 11. Use Horizontal Pod Autoscaling Based on CPU

### Decision

Configure both applications with:

```text
minReplicas: 2
maxReplicas: 5
CPU target:  60%
```

### Rationale

CPU-based HPA is directly supported by the resource requests configured on each workload and provides a simple, verifiable horizontal-scaling policy.

The HPAs successfully reported active CPU metrics during validation.

## 12. Enable Workload Identity

### Decision

Enable the GKE workload pool for both clusters.

### Rationale

This establishes the cluster-side foundation for mapping Kubernetes workloads to Google Cloud identities without designing the sample applications around static credentials.

No application-level cloud-service identity requirement was added solely to demonstrate the feature.

## 13. Use Cloud Logging as the Central Log Collection Layer

### Decision

Enable GKE system and workload logging and validate logs through Cloud Logging.

### Rationale

This matches the assessment observability direction and avoids deploying a separate log collector stack for the exercise.

Cloud Logging queries successfully returned `hello-app` records containing Kubernetes metadata such as cluster, namespace, Pod, container, region, and zone.

## 14. Export Kubernetes Container Logs to BigQuery

### Decision

Create:

```text
Dataset: gke_observability
Sink:    gke-logs-to-bigquery
Filter:  resource.type=k8s_container
```

### Rationale

The assessment specifically requests BigQuery-based log analysis. Exporting GKE container logs creates a queryable data source for cross-cluster log analysis and dashboard-ready SQL.

The export was validated by the appearance of daily stderr/stdout tables and successful SQL queries against live records.

## 15. Do Not Treat ERROR Severity as Application Error Rate

### Decision

Do not calculate application error rate using only:

```sql
severity = 'ERROR'
```

### Rationale

The validated `hello-app` data showed successful `Serving request: /` messages written to stderr and exported with `ERROR` severity.

Therefore severity alone is not a reliable application failure signal for this sample workload.

### Production Evolution

Use structured application telemetry containing explicit outcome fields such as HTTP status, exception type, error class, or another reliable success/failure signal.

## 16. Keep Metrics Claims Separate from Log Evidence

### Decision

Do not fabricate latency percentiles, restart counts, or CPU/memory trends from log fields that do not contain those measurements.

### Rationale

The BigQuery work in this assessment validates log analysis and request/activity time series. CPU/memory utilization, true request latency percentiles, and restart metrics should come from appropriate Kubernetes or Cloud Monitoring metric sources when those data sources are connected.

This keeps the submission evidence-based.

## 17. Defer Grafana When the Required Environment Was Not Available

### Decision

Document Grafana as deferred rather than claiming a dashboard was implemented.

### Rationale

No enabled Grafana-related GCP service was found during implementation, and neither Docker nor a local Grafana server was installed on the workstation. The assessment explicitly allowed unavailable/non-free-tier features to be skipped.

The underlying dashboard-ready path was still completed through:

```text
GKE -> Cloud Logging -> Log Router -> BigQuery
```

## 18. Validate Manually Before Converting Infrastructure to Terraform State

### Decision

Build and verify the initial infrastructure, then create the Terraform definitions and import the validated resources into state.

### Rationale

This assessment was performed interactively. Manual validation established known-good infrastructure first, after which Terraform was used to represent and manage that working state without recreating resources.

### Result

After import and reconciliation, the final Terraform plan reported:

```text
No changes. Your infrastructure matches the configuration.
```

## 19. Keep Terraform and Kubernetes Responsibilities Separate

### Decision

Use Terraform for GCP infrastructure and Kubernetes YAML for in-cluster workloads.

```text
Terraform
  -> VPC
  -> subnets
  -> GKE clusters
  -> BigQuery dataset
  -> Logging sink

Kubernetes YAML
  -> Deployments
  -> HPAs
  -> Services
```

### Rationale

This creates a clear ownership boundary between cloud infrastructure and Kubernetes workload configuration.

## 20. Use Application Default Credentials for Local Terraform Authentication

### Decision

Use the standard local Google provider ADC workflow rather than placing credentials in Terraform configuration.

### Rationale

Normal `gcloud auth login` authentication was sufficient for gcloud but not automatically available to the Terraform Google provider. ADC was configured separately for local Terraform access.

Credential files and access tokens are intentionally excluded from repository artifacts.

## 21. Prefer Least Privilege, but Document Assessment IAM Constraints

### Decision

Use the permissions available in the assessment environment while documenting when a narrower approach was blocked.

### Rationale

A dataset-level IAM operation attempted through the `bq` CLI returned an allowlisting limitation. A broader project-level binding was used for the Logging sink writer in the assessment environment so the export could be validated.

### Production Evolution

Use the narrowest dataset/project IAM scope supported by the organization's policies and tooling.

## 22. Preserve Troubleshooting Evidence

### Decision

Document actual issues encountered instead of presenting the implementation as frictionless.

### Rationale

The assessment explicitly requests a troubleshooting scenario. Real issues encountered included:

- Missing local GKE kubectl authentication plugin
- Missing Terraform Application Default Credentials
- Dataset-level IAM CLI allowlisting limitation
- Minimal `hello-app` container without `wget`
- A YAML formatting/parsing issue during manifest conversion

These events demonstrate validation, diagnosis, and adaptation and are documented separately in `troubleshooting.md`.

## 23. Production Architecture vs. Assessment Architecture

The implemented environment is intentionally narrower than the full reference architecture.

### Implemented

```text
Custom VPC
Two regional GKE clusters
Dedicated VPC-native subnets
Two replicated applications
Health probes
HPA
Primary public endpoints
Cloud Logging
BigQuery export and queries
Terraform-managed GCP resources
```

### Documented Production Evolution

```text
Global HTTPS load balancing
Cloud DNS
Multi-cluster ingress/services
Cloud Armor
Private nodes and Cloud NAT
Service mesh / mTLS
Secret Manager integration
Distributed tracing and profiling
Multi-zone worker placement
Production-grade dashboarding
Reliable structured application error/latency telemetry
```

This distinction prevents architecture intent from being misrepresented as implemented functionality.

## Summary

The overall design favors a small but real and verifiable implementation over a larger architecture that is only partially functional. The assessment environment demonstrates the core operational path:

```text
Infrastructure -> GKE -> Workloads -> Scaling -> Endpoint -> Logging -> BigQuery -> Terraform
```

while preserving a clear path to the more advanced security, availability, global traffic, and observability features expected in a production environment.
