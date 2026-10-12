# Setup Guide

This guide documents the step-by-step setup used for the GKE SRE assessment implementation. It is intended to make the environment understandable and reproducible while preserving a clear distinction between infrastructure provisioning, Kubernetes workload deployment, and observability configuration.

## 1. Assessment Environment

GCP project:

```text
Project name: CS SRE Assessment
Project ID:   project-19ae3503-8d3c-48b5-9d8
```

Implemented regional design:

```text
Primary region:   us-central1
Secondary region: us-east1
```

The implementation uses GKE Standard clusters, VPC-native networking, two stateless applications, Horizontal Pod Autoscaling, Cloud Logging, BigQuery log export, Grafana dashboarding, Multi-Cluster Services (MCS), Multi-Cluster Ingress (MCI), Workload Identity, IAM role separation, and Terraform-managed infrastructure.

## 2. Local Tooling

The workstation requires:

```text
Google Cloud CLI
kubectl
gke-gcloud-auth-plugin
Terraform
bq CLI
```

Verify the main tools:

```powershell
gcloud --version
kubectl version --client
terraform version
```

## 3. Authenticate and Select the Project

Authenticate the Google Cloud CLI:

```powershell
gcloud auth login
```

Verify the active account:

```powershell
gcloud auth list
```

Select the assessment project:

```powershell
gcloud config set project project-19ae3503-8d3c-48b5-9d8
```

Set the primary default compute region:

```powershell
gcloud config set compute/region us-central1
```

Verify configuration:

```powershell
gcloud config get-value account
gcloud config get-value project
gcloud config get-value compute/region
```

Verify project access:

```powershell
gcloud projects describe project-19ae3503-8d3c-48b5-9d8
```

## 4. Enable the Kubernetes Engine API

Check whether the API is enabled:

```powershell
gcloud services list --enabled --filter="NAME:container.googleapis.com"
```

If it is not enabled:

```powershell
gcloud services enable container.googleapis.com
```

Verify again:

```powershell
gcloud services list --enabled --filter="NAME:container.googleapis.com"
```

## 5. Network Architecture

The assessment uses a dedicated custom-mode VPC rather than the default auto-mode network.

```text
sre-assessment-vpc
|
|-- gke-primary-subnet
|   |-- nodes:    10.10.0.0/20
|   |-- pods:     10.20.0.0/16
|   `-- services: 10.30.0.0/20
|
`-- gke-secondary-subnet
    |-- nodes:    10.40.0.0/20
    |-- pods:     10.50.0.0/16
    `-- services: 10.60.0.0/20
```

### Create the VPC

```powershell
gcloud compute networks create sre-assessment-vpc --subnet-mode=custom
```

### Create the primary subnet

```powershell
gcloud compute networks subnets create gke-primary-subnet --network=sre-assessment-vpc --region=us-central1 --range=10.10.0.0/20 --secondary-range=gke-primary-pods=10.20.0.0/16,gke-primary-services=10.30.0.0/20
```

Verify:

```powershell
gcloud compute networks subnets describe gke-primary-subnet --region=us-central1
```

### Create the secondary subnet

```powershell
gcloud compute networks subnets create gke-secondary-subnet --network=sre-assessment-vpc --region=us-east1 --range=10.40.0.0/20 --secondary-range=gke-secondary-pods=10.50.0.0/16,gke-secondary-services=10.60.0.0/20
```

Verify:

```powershell
gcloud compute networks subnets describe gke-secondary-subnet --region=us-east1
```

## 6. Create GKE Clusters

Both assessment clusters use GKE Standard, the Regular release channel, `e2-standard-2` worker nodes, VPC-native networking, Workload Identity, logging, monitoring, and cluster node autoscaling.

### Primary cluster

```powershell
gcloud container clusters create gke-primary --region=us-central1 --node-locations=us-central1-a --release-channel=regular --machine-type=e2-standard-2 --num-nodes=2 --enable-autoscaling --min-nodes=1 --max-nodes=3 --network=sre-assessment-vpc --subnetwork=gke-primary-subnet --enable-ip-alias --cluster-secondary-range-name=gke-primary-pods --services-secondary-range-name=gke-primary-services --workload-pool=project-19ae3503-8d3c-48b5-9d8.svc.id.goog --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM
```

### Secondary cluster

```powershell
gcloud container clusters create gke-secondary --region=us-east1 --node-locations=us-east1-b --release-channel=regular --machine-type=e2-standard-2 --num-nodes=2 --enable-autoscaling --min-nodes=1 --max-nodes=3 --network=sre-assessment-vpc --subnetwork=gke-secondary-subnet --enable-ip-alias --cluster-secondary-range-name=gke-secondary-pods --services-secondary-range-name=gke-secondary-services --workload-pool=project-19ae3503-8d3c-48b5-9d8.svc.id.goog --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM
```

Verify both clusters:

```powershell
gcloud container clusters list
```

## 7. Configure kubectl Access

If necessary, install the Kubernetes client and GKE authentication plugin using the Google Cloud CLI component manager available with the local SDK installation.

Obtain primary credentials:

```powershell
gcloud container clusters get-credentials gke-primary --region=us-central1
kubectl config current-context
kubectl get nodes
```

Obtain secondary credentials:

```powershell
gcloud container clusters get-credentials gke-secondary --region=us-east1
kubectl config current-context
kubectl get nodes
```

Always verify the active context before a cluster-specific change:

```powershell
kubectl config current-context
```

## 8. Deploy Kubernetes Workloads

Kubernetes manifests are stored in:

```text
../kubernetes/
```

Shared workload manifests:

```text
app-a.yaml
app-b.yaml
```

Primary-only public services:

```text
primary-services.yaml
```

### Primary deployment

```powershell
gcloud container clusters get-credentials gke-primary --region=us-central1
kubectl config current-context
kubectl apply --dry-run=server -f ../kubernetes/app-a.yaml
kubectl apply --dry-run=server -f ../kubernetes/app-b.yaml
kubectl apply --dry-run=server -f ../kubernetes/primary-services.yaml
kubectl apply -f ../kubernetes/app-a.yaml
kubectl apply -f ../kubernetes/app-b.yaml
kubectl apply -f ../kubernetes/primary-services.yaml
```

Verify:

```powershell
kubectl get deployments
kubectl get pods -o wide
kubectl get hpa
kubectl get services
```

### Secondary deployment

```powershell
gcloud container clusters get-credentials gke-secondary --region=us-east1
kubectl config current-context
kubectl apply --dry-run=server -f ../kubernetes/app-a.yaml
kubectl apply --dry-run=server -f ../kubernetes/app-b.yaml
kubectl apply -f ../kubernetes/app-a.yaml
kubectl apply -f ../kubernetes/app-b.yaml
```

Do not apply `primary-services.yaml` to the secondary cluster.

Verify:

```powershell
kubectl get deployments
kubectl get pods -o wide
kubectl get hpa
```

## 9. IAM role separation was implemented for:

- Developers
- Operations
- SRE
- CI/CD

Implementation details and role assignments are documented in:

../docs/iam-design.md
../terraform/iam.tf

## 10. Validate Primary Application Endpoints

On the primary cluster:

```powershell
gcloud container clusters get-credentials gke-primary --region=us-central1
kubectl get service app-a-service
kubectl get service app-b-service
```

Test each assigned external IP:

```powershell
curl http://APP_A_EXTERNAL_IP
curl http://APP_B_EXTERNAL_IP
```

The validated assessment implementation returned the NGINX welcome response for App A and the sample `Hello, world!` response for App B.

## 11. Verify Horizontal Pod Autoscaling

```powershell
kubectl get hpa
kubectl describe hpa app-a
kubectl describe hpa app-b
```

Both workload HPAs are configured for:

```text
Minimum replicas: 2
Maximum replicas: 5
CPU target:       60%
```

After both clusters were deployed and validated, Multi-Cluster Services (MCS) and Multi-Cluster Ingress (MCI) were configured to provide global traffic routing and cross-region failover.

Traffic flow:

```text
Internet
    |
    v
Global Load Balancer
    |
    v
Multi-Cluster Ingress (MCI)
    |
    v
Multi-Cluster Services (MCS)
    |
    +------> gke-primary
    |
    +------> gke-secondary
```

## 12. Multi-Cluster Services and Ingress

After both GKE clusters were deployed and validated, Multi-Cluster Services (MCS) and Multi-Cluster Ingress (MCI) were configured to provide global traffic routing, cross-region service discovery, and health-based failover.

Traffic flow:

```text
Internet
    |
    v
Global Load Balancer
    |
    v
Multi-Cluster Ingress (MCI)
    |
    v
Multi-Cluster Services (MCS)
    |
    +------> gke-primary
    |
    +------> gke-secondary
```

Validated capabilities include:

- Global VIP
- Cross-region traffic routing
- Health-based failover
- Multi-cluster service discovery
- Cross-region workload access

Additional documentation:

```text
../docs/multiclusteringress-evidence
../docs/SSL-termination.md
```

## 13. Validate Cloud Logging

A workload-log query can be performed using the Google Cloud CLI.

Example for App B on the secondary cluster:

```powershell
gcloud logging read "resource.type=k8s_container AND resource.labels.cluster_name=gke-secondary AND resource.labels.container_name=hello-app" --limit=10
```

The validated records included GKE metadata such as cluster name, location, namespace, Pod, and container.

## 14. Create the BigQuery Dataset

Verify the BigQuery API:

```powershell
gcloud services list --enabled --filter="NAME:bigquery.googleapis.com"
```

Create the dataset:

```powershell
bq --location=US mk --dataset project-19ae3503-8d3c-48b5-9d8:gke_observability
```

Verify:

```powershell
bq ls
```

## 15. Create the Cloud Logging Sink

Create a project Logging sink for Kubernetes container logs:

```powershell
gcloud logging sinks create gke-logs-to-bigquery bigquery.googleapis.com/projects/project-19ae3503-8d3c-48b5-9d8/datasets/gke_observability --log-filter="resource.type=k8s_container"
```

Inspect the sink and record its writer identity:

```powershell
gcloud logging sinks describe gke-logs-to-bigquery
```

The sink writer requires appropriate BigQuery write permissions. In this assessment environment, a dataset-level `bq add-iam-policy-binding` attempt returned an allowlisting limitation, so permission was provided through a project-level IAM binding instead. In a production environment, use the narrowest supported IAM scope.

Generate fresh workload traffic, allow time for export, and verify tables:

```powershell
bq ls project-19ae3503-8d3c-48b5-9d8:gke_observability
```

The validated export created daily stderr and stdout tables.

## 16. Run BigQuery Analysis

Queries are stored in:

```text
../queries/observability.sql
```

Example validation query:

```powershell
bq query --use_legacy_sql=false "SELECT timestamp, severity, textPayload FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006` ORDER BY timestamp DESC LIMIT 10"
```

See `../queries/README.md` for the full query set and interpretation notes.

## 17. Install and Configure Terraform

Terraform was installed locally and initialized under:

```text
../terraform/
```

The Google Terraform provider requires Application Default Credentials for this local workflow:

```powershell
gcloud auth application-default login
```

Initialize and validate:

```powershell
cd ../terraform
terraform init
terraform fmt
terraform validate
```

## 18. Import Existing Validated Infrastructure into Terraform

The infrastructure was created and verified before Terraform state management was introduced. The existing resources were then imported rather than recreated.

Imports used:

```powershell
terraform import google_compute_network.sre_vpc projects/project-19ae3503-8d3c-48b5-9d8/global/networks/sre-assessment-vpc
terraform import google_compute_subnetwork.primary projects/project-19ae3503-8d3c-48b5-9d8/regions/us-central1/subnetworks/gke-primary-subnet
terraform import google_compute_subnetwork.secondary projects/project-19ae3503-8d3c-48b5-9d8/regions/us-east1/subnetworks/gke-secondary-subnet
terraform import google_container_cluster.primary projects/project-19ae3503-8d3c-48b5-9d8/locations/us-central1/clusters/gke-primary
terraform import google_container_cluster.secondary projects/project-19ae3503-8d3c-48b5-9d8/locations/us-east1/clusters/gke-secondary
terraform import google_bigquery_dataset.gke_observability projects/project-19ae3503-8d3c-48b5-9d8/datasets/gke_observability
terraform import google_logging_project_sink.gke_logs_to_bigquery projects/project-19ae3503-8d3c-48b5-9d8/sinks/gke-logs-to-bigquery
```

Check Terraform state:

```powershell
terraform state list
```

## 19. Confirm Terraform Drift State

Run:

```powershell
terraform plan
```

After the configuration and imported infrastructure were reconciled, the validated final result was:

```text
No changes. Your infrastructure matches the configuration.
```

This is the expected steady state for the completed assessment resources.

## 20. Grafana Dashboard Validation

Grafana was configured and validated using the assessment observability pipeline.

Observability flow:

```text
GKE Workloads
    |
    v
Cloud Logging
    |
    v
BigQuery
    |
    v
Grafana
```

Evidence and dashboard exports are available under:

```text
../grafana/
```

Dashboard validation includes:

- Application activity analysis
- Error visibility
- Request trend analysis
- Cluster activity reporting
- BigQuery-backed observability dashboards

## 21. Evidence to Capture

Recommended assessment evidence:

```text
- gcloud container clusters list
- Primary and secondary kubectl pod output
- HPA status
- Primary App A endpoint screenshot
- Primary App B endpoint screenshot
- Multi-Cluster Ingress evidence
- Global VIP evidence
- Cloud Logging query output
- BigQuery dataset/table listing
- BigQuery query results
- Grafana dashboard screenshots
- IAM architecture documentation
- SSL termination documentation
- terraform validate
- terraform state list
- final terraform plan showing no changes
```

## 22. Troubleshooting Scenarios Encountered

### Missing GKE kubectl authentication plugin

The cluster was successfully created, but local kubectl access initially reported the required GKE authentication plugin was missing. After the required local Kubernetes/GKE client tooling was installed and credentials refreshed, `kubectl get nodes` returned healthy nodes.

### Application Default Credentials missing for Terraform

The Google Cloud CLI was authenticated, but Terraform initially failed because Application Default Credentials had not been configured. Running the ADC login flow allowed the Google provider to import the existing resources.

### BigQuery dataset-level IAM CLI limitation

A dataset-level IAM binding attempt returned an allowlisting limitation. The assessment environment used a project-level permission for the Logging sink writer identity. Exported BigQuery log tables subsequently appeared.

### Minimal sample container lacked wget

The `hello-app` image did not contain `wget`. Kubernetes port forwarding and requests from the workstation were used instead to generate fresh traffic without altering the application container.

## 23. Safety Notes

- Verify the active GCP project before provisioning or changing infrastructure.
- Verify `kubectl config current-context` before every Kubernetes apply.
- Use `kubectl apply --dry-run=server` before cluster changes.
- Review every Terraform plan before applying changes.
- Stop if Terraform proposes unexpected replacement or destruction.
- Do not commit credentials, ADC tokens, kubeconfig secrets, or other sensitive information to the repository.
- Do not apply `primary-services.yaml` to the secondary cluster.

## Related Documentation

```text
../README.md
../terraform/README.md
../kubernetes/README.md
../queries/README.md
```
