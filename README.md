# GKE SRE Assessment

This repository contains the implementation and supporting documentation for a Google Cloud / Google Kubernetes Engine SRE assessment. The implementation focuses on a reproducible two-region GKE design, stateless multi-pod applications, autoscaling, public endpoint validation, centralized logging, BigQuery-based log analysis, and Terraform-managed infrastructure.

## Project Summary

**GCP project:** `project-19ae3503-8d3c-48b5-9d8`  
**Project name:** `CS SRE Assessment`

### Implemented architecture

- Custom VPC: `sre-assessment-vpc`
- Primary GKE cluster: `gke-primary` in `us-central1`
- Secondary GKE cluster: `gke-secondary` in `us-east1`
- Dedicated VPC-native subnet and secondary Pod/Service ranges for each cluster
- Two stateless applications deployed with multiple replicas
- CPU and memory requests/limits
- Readiness and liveness probes
- Horizontal Pod Autoscaling targeting 60% CPU utilization
- Public LoadBalancer Services on the primary cluster for endpoint validation
- GKE container logs collected in Cloud Logging
- Log Router sink exporting Kubernetes container logs to BigQuery
- BigQuery dataset: `gke_observability`
- Terraform configuration for the VPC, subnets, GKE clusters, BigQuery dataset, and Logging sink
- Local Grafana OSS observability dashboard
- Google OAuth authentication for Grafana
- BigQuery Forward OAuth Identity integration
- Four dashboard panels visualizing GKE application and log activity
- Terraform-ready IAM model for Developer, Operations, SRE, and CI/CD personas
- Conditional IAM bindings that create no access until real organization-managed principals are supplied
- Separation of human group access from CI/CD machine identity
- Keyless/federated authentication preferred for CI/CD automation

## Architecture

```text
                         Internet
                            |
                  Primary public endpoints
                            |
                    gke-primary
                    us-central1
                    /         \
                 App A       App B
                 2+ pods     2+ pods
                    \         /
                     \       /
                  sre-assessment-vpc
                     /       \
                    /         \
          gke-primary-subnet   gke-secondary-subnet
               |                     |
        gke-primary             gke-secondary
        us-central1               us-east1
                                   /      \
                                App A    App B
                                2+ pods  2+ pods

GKE container logs
        |
        v
Cloud Logging
        |
        v
gke-logs-to-bigquery
        |
        v
BigQuery: gke_observability
```

The assessment implementation keeps public LoadBalancer Services primary-specific. The production architecture described in the assessment can evolve toward a single global HTTPS entry point with multi-cluster traffic management, health-based failover, DNS, and WAF controls.

## IAM Design

The assessment defines a least-privilege IAM model separating human access and deployment automation across four personas:

| Persona | Primary Responsibility |
|---|---|
| Developers | Application deployment, application-level troubleshooting, logs, and workload visibility |
| Operations | GKE platform operations, infrastructure visibility, and runtime support |
| SRE | Reliability, GKE operations, Cloud Logging, Cloud Monitoring, Managed Prometheus, and observability analysis |
| CI/CD | Automated infrastructure and application deployment using a dedicated non-human identity |

Human access is designed around organization-managed groups rather than individual IAM assignments. Kubernetes RBAC provides an additional in-cluster authorization boundary, allowing application and operational permissions to be scoped independently of GCP project access.

CI/CD automation is designed to use short-lived or federated workload identity rather than human credentials or long-lived service-account keys. The assessment project enforces a policy preventing service-account key creation, and that security control was preserved during implementation.

The supplied assessment environment does not provide organization-managed Developer, Operations, or SRE groups, so artificial users or groups were not created solely to satisfy the architecture. The implemented project owner access is treated as assessment provisioning access rather than the recommended production authorization model.

A production implementation would use:

- Organization-managed groups for Developers, Operations, and SRE
- Dedicated non-human identity for CI/CD
- Least-privilege predefined or custom IAM roles
- Namespace-scoped Kubernetes RBAC where appropriate
- Workload Identity Federation for external CI/CD systems such as GitHub Actions
- Separate infrastructure and application deployment identities where stronger separation of duties is required
- Periodic IAM access review and audit-log monitoring

The complete IAM model, persona boundaries, human-versus-machine identity strategy, BigQuery access separation, and production recommendations are documented in:

`docs/iam-design.md`

## Network Design

| Cluster | Region | Subnet | Node CIDR | Pod CIDR | Service CIDR |
|---|---|---|---|---|---|
| Primary | `us-central1` | `gke-primary-subnet` | `10.10.0.0/20` | `10.20.0.0/16` | `10.30.0.0/20` |
| Secondary | `us-east1` | `gke-secondary-subnet` | `10.40.0.0/20` | `10.50.0.0/16` | `10.60.0.0/20` |

Both clusters use VPC-native alias IP addressing.

## Applications

### App A

- Image: `nginx:1.27`
- Initial replicas: 2
- HTTP port: 80
- CPU request: `100m`
- CPU limit: `250m`
- Memory request: `64Mi`
- Memory limit: `128Mi`
- Readiness probe: HTTP `/`
- Liveness probe: HTTP `/`
- HPA: 2 to 5 replicas at 60% CPU utilization

### App B

- Image: `gcr.io/google-samples/hello-app:1.0`
- Initial replicas: 2
- Container port: 8080
- CPU request: `100m`
- CPU limit: `250m`
- Memory request: `64Mi`
- Memory limit: `128Mi`
- Readiness probe: HTTP `/`
- Liveness probe: HTTP `/`
- HPA: 2 to 5 replicas at 60% CPU utilization

Primary-cluster endpoint testing successfully returned the NGINX welcome page for App A and the `Hello, world!` response for App B.

## Repository Layout

```text
gke-sre-assessment/
|
|-- README.md
|
|-- terraform/
|   |-- versions.tf
|   |-- provider.tf
|   |-- variables.tf
|   |-- network.tf
|   |-- gke.tf
|   `-- observability.tf
|
|-- kubernetes/
|   |-- README.md
|   |-- app-a.yaml
|   |-- app-b.yaml
|   `-- primary-services.yaml
|
|-- queries/
|   |-- README.md
|   `-- observability.sql
|
`-- docs/
    |-- architecture.*
    |-- setup.md
    |-- design-decisions.md
    `-- troubleshooting.md
```

## Terraform

Terraform manages the implemented infrastructure after the manually validated resources were imported into state.

Managed resources include:

- `sre-assessment-vpc`
- `gke-primary-subnet`
- `gke-secondary-subnet`
- `gke-primary`
- `gke-secondary`
- `gke_observability`
- `gke-logs-to-bigquery`

Basic validation workflow:

```powershell
cd terraform
terraform init
terraform fmt
terraform validate
terraform plan
```

The final plan after import and reconciliation returned:

```text
No changes. Your infrastructure matches the configuration.
```

Do not run `terraform apply` against an existing assessment environment unless the plan has been reviewed and the change is intentional.

## IAM Design

The project includes a Terraform-ready least-privilege IAM model for four personas:

| Persona | Responsibility |
|---|---|
| Developers | Application visibility, logging, monitoring, and application-level troubleshooting |
| Operations | GKE and compute visibility, logging, monitoring, and runtime operations |
| SRE | GKE operations, observability, reliability analysis, logging, monitoring, and BigQuery querying |
| CI/CD | Automated workload deployment through a dedicated non-human identity |

The IAM implementation is defined in:

```text
terraform/iam.tf
```

## Kubernetes Deployment

The workload manifests are split so shared resources can be safely applied to both clusters while public services remain primary-specific.

### Primary

```powershell
gcloud container clusters get-credentials gke-primary --region=us-central1
kubectl config current-context
kubectl apply --dry-run=server -f kubernetes/app-a.yaml
kubectl apply --dry-run=server -f kubernetes/app-b.yaml
kubectl apply --dry-run=server -f kubernetes/primary-services.yaml
kubectl apply -f kubernetes/app-a.yaml
kubectl apply -f kubernetes/app-b.yaml
kubectl apply -f kubernetes/primary-services.yaml
```

### Secondary

```powershell
gcloud container clusters get-credentials gke-secondary --region=us-east1
kubectl config current-context
kubectl apply --dry-run=server -f kubernetes/app-a.yaml
kubectl apply --dry-run=server -f kubernetes/app-b.yaml
kubectl apply -f kubernetes/app-a.yaml
kubectl apply -f kubernetes/app-b.yaml
```

Do **not** apply `primary-services.yaml` to `gke-secondary`.

See `kubernetes/README.md` for the detailed deployment procedure and operational checks.

## Observability

### Logging pipeline

```text
GKE workloads
    |
    v
Cloud Logging
    |
    v
Log Router sink: gke-logs-to-bigquery
    |
    v
BigQuery dataset: gke_observability
```

The export produced tables including:

- `stderr_20261006`
- `stdout_20261006`

Live queries verified application records from both `gke-primary` and `gke-secondary`.

### Important logging observation

The sample `hello-app` writes successful `Serving request: /` messages to stderr. Those exported records can therefore appear with `ERROR` severity even when the HTTP request succeeds. For this reason, application error analysis should not treat every `ERROR`-severity record as a failed request. Queries should also use workload metadata and application message content.

## Example BigQuery Queries

### Recent log records

```sql
SELECT
  timestamp,
  severity,
  textPayload
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006`
ORDER BY timestamp DESC
LIMIT 10;
```

### Log volume over time

```sql
SELECT
  TIMESTAMP_TRUNC(timestamp, MINUTE) AS minute,
  COUNT(*) AS log_count
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006`
GROUP BY minute
ORDER BY minute;
```

### Application activity by cluster

```sql
SELECT
  resource.labels.cluster_name AS cluster,
  COUNT(*) AS log_count
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006`
WHERE resource.labels.container_name = 'hello-app'
GROUP BY cluster
ORDER BY log_count DESC;
```

### Request traffic over time by cluster

```sql
SELECT
  TIMESTAMP_TRUNC(timestamp, MINUTE) AS time,
  resource.labels.cluster_name AS cluster,
  COUNT(*) AS request_count
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006`
WHERE resource.labels.container_name = 'hello-app'
  AND textPayload LIKE '%Serving request:%'
GROUP BY time, cluster
ORDER BY time;
```

Additional queries should be stored in `queries/observability.sql`.

## Grafana Dashboard

Grafana OSS was installed locally on Windows and connected to the assessment's BigQuery observability dataset.

### Authentication

The GCP project enforces:

```text
constraints/iam.disableServiceAccountKeyCreation
```

## Troubleshooting Notes

Several real implementation issues provided useful troubleshooting evidence:

1. **GKE kubectl authentication plugin missing**
   - Cluster creation succeeded, but local kubectl access warned that `gke-gcloud-auth-plugin` was unavailable.
   - After the required client/authentication tooling was installed and cluster credentials refreshed, `kubectl get nodes` successfully returned Ready nodes.

2. **Terraform Application Default Credentials missing**
   - Normal `gcloud auth login` credentials worked for gcloud, but the Terraform Google provider initially could not find Application Default Credentials.
   - ADC was configured separately, after which Terraform successfully imported the existing GCP resources.

3. **Dataset-level IAM CLI limitation**
   - A `bq add-iam-policy-binding` attempt returned `This feature requires allowlisting`.
   - A project-level IAM binding was used for the Logging sink writer identity, and the BigQuery export subsequently created log tables.

4. **Minimal hello-app container tooling**
   - The sample application container did not include `wget`, so in-container traffic generation was not used.
   - Kubernetes port forwarding and local HTTP requests provided a non-invasive alternative for generating fresh traffic.

5. **Grafana BigQuery authentication under the service-account-key restriction**
   - The GCP project enforced `constraints/iam.disableServiceAccountKeyCreation`, preventing creation of a long-lived Grafana service-account JSON key.
   - Grafana's GCE Default Service Account mode did not successfully discover local workstation Application Default Credentials.
   - The integration was moved to Google OAuth with Forward OAuth Identity instead of weakening the project security policy.
   - The Google OAuth application was configured for the local Grafana callback, the assessment account was added as a test user, and the BigQuery data source subsequently passed its connection test.
   - The resulting Grafana dashboard successfully queried the `gke_observability` BigQuery dataset.

These issues are recorded as implementation evidence rather than hidden from the assessment.

## Design Decisions

- **GKE Standard** was used to demonstrate direct node-pool and operational control.
- **One custom VPC** provides shared connectivity with dedicated regional subnets per cluster.
- **VPC-native alias IP ranges** separate node, Pod, and Service address spaces.
- **Two regional clusters** demonstrate cross-region workload replication.
- **Two replicas plus HPA** provide a simple baseline for availability and horizontal scaling.
- **Primary-only public Services** keep the assessment implementation simple and avoid unnecessary public load balancers in the secondary cluster.
- **Cloud Logging to BigQuery** provides centralized, queryable application and GKE log data.
- **Terraform import followed by zero-drift plan** converts the manually validated infrastructure into reproducible IaC without recreating working resources.
- **IAM is modeled using conditional Terraform bindings** so the repository documents a least-privilege Developer, Operations, SRE, and CI/CD access strategy without creating fake principals. Human access is intended to use organization-managed groups, while automation should use dedicated workload identities and keyless authentication.

## Production Evolution

The assessment implementation intentionally prioritizes validated core functionality and reproducibility. A fuller production implementation can add:

- Global external HTTPS load balancing
- Multi-cluster ingress/services
- Cloud DNS
- TLS certificates
- Cloud Armor WAF policies
- Private GKE nodes and Cloud NAT
- Secret Manager integration
- Service mesh and mTLS
- Distributed tracing and profiling
- Multi-zone node placement and topology spread constraints
- Production-hosted Grafana or managed observability platform
- Organization-managed Developer, Operations, and SRE groups
- Workload Identity Federation for GitHub Actions / CI/CD
- Separate application and infrastructure deployment identities
- IAM Conditions and periodic access reviews
- Privileged-access elevation rather than routine Owner access

## Evidence Checklist

Recommended submission evidence:

- [ ] Screenshot of App A public endpoint
- [ ] Screenshot of App B public endpoint
- [ ] `kubectl get pods -o wide` for primary
- [ ] `kubectl get pods -o wide` for secondary
- [ ] `kubectl get hpa`
- [ ] `gcloud container clusters list`
- [ ] BigQuery query result screenshots
- [ ] Terraform `No changes` plan output
- [ ] Architecture diagram
- [ ] Troubleshooting write-up
- [ ] Full Grafana dashboard screenshot showing all four panels
- [ ] Exported `grafana/gke-sre-observability-dashboard.json`
- [ ] `terraform/iam.tf` showing conditional Dev/Ops/SRE/CI/CD IAM model
- [ ] `docs/iam-design.md` documenting persona boundaries and least-privilege strategy
- [ ] Terraform plan showing no unintended IAM changes

## Safety / Operator Notes

- Verify the active GCP project before provisioning resources.
- Verify `kubectl config current-context` before every cluster-specific apply.
- Use server-side dry runs before applying Kubernetes manifest changes.
- Do not apply `kubernetes/primary-services.yaml` to the secondary cluster.
- Review every Terraform plan before applying changes.
- Treat Application Default Credential access tokens as sensitive and do not record them in repository documentation.
