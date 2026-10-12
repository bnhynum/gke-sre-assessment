# GKE SRE Assessment Kubernetes Manifests

This directory contains the Kubernetes manifests used to deploy two stateless web applications across the primary and secondary GKE clusters.

The deployment design supports:

- Multi-pod application deployments
- Horizontal Pod Autoscaling (HPA)
- Configuration through ConfigMaps and Secrets
- Cross-region workload replication
- Regional resilience through deployment to both GKE clusters

As required by the assessment, both applications are deployed to the primary and secondary clusters to support high availability and future failover scenarios. 【1-505b68】【2-fabe6e】

---

## Files

| File | Purpose |
|--------|---------|
| `app-a.yaml` | App A Deployment, ConfigMap, Secret, Service, and HorizontalPodAutoscaler |
| `app-b.yaml` | App B Deployment, Service, and HorizontalPodAutoscaler |
| `primary-services.yaml` | Primary-cluster public LoadBalancer Services for endpoint validation |

The workload manifests are applied to both clusters.

Public LoadBalancer Services are intentionally maintained in a separate manifest to prevent accidental creation of public endpoints in the secondary cluster.

---

## Cluster Layout

```text
gke-primary (us-central1)
├── App A
├── App B
├── HPA
└── Public LoadBalancer Services

gke-secondary (us-east1)
├── App A
├── App B
└── HPA
```

Both clusters run the same application workloads to maintain deployment symmetry and support regional redundancy.

---

## Prerequisites

Verify the active Kubernetes context before running any commands:

```bash
kubectl config current-context
```

List all available contexts:

```bash
kubectl config get-contexts
```

---

## Validate Before Applying

Validate manifests with Kubernetes server-side dry run:

```bash
kubectl apply --dry-run=server -f app-a.yaml
kubectl apply --dry-run=server -f app-b.yaml
```

Validate the primary-only services:

```bash
gcloud container clusters get-credentials gke-primary --region=us-central1

kubectl config current-context

kubectl apply --dry-run=server -f primary-services.yaml
```

---

## Apply to Primary Cluster

Select the primary cluster:

```bash
gcloud container clusters get-credentials gke-primary --region=us-central1

kubectl config current-context
```

Deploy the shared workloads:

```bash
kubectl apply -f app-a.yaml
kubectl apply -f app-b.yaml
```

Deploy the public-facing services:

```bash
kubectl apply -f primary-services.yaml
```

Verify deployment:

```bash
kubectl get deployments
kubectl get pods -o wide
kubectl get hpa
kubectl get services
```

---

## Apply to Secondary Cluster

Select the secondary cluster:

```bash
gcloud container clusters get-credentials gke-secondary --region=us-east1

kubectl config current-context
```

Deploy the shared workloads:

```bash
kubectl apply -f app-a.yaml
kubectl apply -f app-b.yaml
```

Do **not** apply `primary-services.yaml` to the secondary cluster.

The secondary cluster is intended to host replicated workloads without creating separate public LoadBalancer endpoints.

Verify deployment:

```bash
kubectl get deployments
kubectl get pods -o wide
kubectl get hpa
kubectl get services
```

---

## Recommended Apply Order

### Primary

```bash
gcloud container clusters get-credentials gke-primary --region=us-central1

kubectl apply --dry-run=server -f app-a.yaml
kubectl apply --dry-run=server -f app-b.yaml
kubectl apply --dry-run=server -f primary-services.yaml

kubectl apply -f app-a.yaml
kubectl apply -f app-b.yaml
kubectl apply -f primary-services.yaml
```

### Secondary

```bash
gcloud container clusters get-credentials gke-secondary --region=us-east1

kubectl apply --dry-run=server -f app-a.yaml
kubectl apply --dry-run=server -f app-b.yaml

kubectl apply -f app-a.yaml
kubectl apply -f app-b.yaml
```

---

## Operational Verification

### Deployment Health

```bash
kubectl rollout status deployment/app-a
kubectl rollout status deployment/app-b
```

### Workload Status

```bash
kubectl get deployments
kubectl get pods -o wide
kubectl get services
kubectl get endpoints
```

### Autoscaling

```bash
kubectl get hpa

kubectl describe hpa app-a
kubectl describe hpa app-b
```

### Application Logs

```bash
kubectl logs deployment/app-a --tail=50
kubectl logs deployment/app-b --tail=50
```

### Public Endpoint Validation

Primary cluster only:

```bash
kubectl get service app-a-service
kubectl get service app-b-service
```

---

## Multi-Cluster Architecture Note

This directory manages application workloads only.

The broader assessment architecture also includes:

- Multi-Cluster Services (MCS)
- Multi-Cluster Ingress (MCI)
- Global load balancing
- Cross-region failover
- Health-check-based traffic management

These components are configured separately from the workload manifests contained in this directory.

The public LoadBalancer Services defined in `primary-services.yaml` are retained for direct application endpoint validation required by the assessment.

---

## Safety Notes

- Always verify `kubectl config current-context` before applying changes.
- Use `--dry-run=server` prior to applying modified manifests.
- Apply `primary-services.yaml` only while connected to `gke-primary`.
- Verify rollout status after every deployment.
- Confirm HPA resources are healthy after deployment.
- Review resources in both clusters to maintain deployment symmetry.