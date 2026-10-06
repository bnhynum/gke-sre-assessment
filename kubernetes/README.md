# GKE SRE Assessment Kubernetes Manifests

This directory contains Kubernetes manifests for two stateless web applications deployed to the primary and secondary GKE clusters.

## Files

- `app-a.yaml` - App A Deployment and HorizontalPodAutoscaler
- `app-b.yaml` - App B Deployment and HorizontalPodAutoscaler
- `primary-services.yaml` - Primary-cluster public LoadBalancer Services for App A and App B

The application and autoscaling manifests are shared by both clusters. Public LoadBalancer Services are intentionally kept separate so they are not accidentally created in the secondary/DR cluster.

## Prerequisites

Before applying manifests, verify the active Kubernetes context:

```powershell
kubectl config current-context
```

You can list all configured contexts with:

```powershell
kubectl config get-contexts
```

## Validate Before Applying

Server-side dry-run validation does not persist changes:

```powershell
kubectl apply --dry-run=server -f app-a.yaml
kubectl apply --dry-run=server -f app-b.yaml
```

For the primary-only services, first select the primary cluster and then validate:

```powershell
gcloud container clusters get-credentials gke-primary --region=us-central1
kubectl config current-context
kubectl apply --dry-run=server -f primary-services.yaml
```

## Apply to Primary Cluster

Select the primary cluster:

```powershell
gcloud container clusters get-credentials gke-primary --region=us-central1
kubectl config current-context
```

Apply the common workloads and HPAs:

```powershell
kubectl apply -f app-a.yaml
kubectl apply -f app-b.yaml
```

Apply the primary-cluster public Services:

```powershell
kubectl apply -f primary-services.yaml
```

Verify:

```powershell
kubectl get deployments
kubectl get pods -o wide
kubectl get hpa
kubectl get services
```

## Apply to Secondary Cluster

Select the secondary cluster:

```powershell
gcloud container clusters get-credentials gke-secondary --region=us-east1
kubectl config current-context
```

Apply only the shared workload and HPA manifests:

```powershell
kubectl apply -f app-a.yaml
kubectl apply -f app-b.yaml
```

Do **not** apply `primary-services.yaml` to the secondary cluster. This avoids provisioning separate public LoadBalancer Services and external IP addresses in the DR cluster.

Verify:

```powershell
kubectl get deployments
kubectl get pods -o wide
kubectl get hpa
kubectl get services
```

## Recommended Apply Order

Primary:

```powershell
gcloud container clusters get-credentials gke-primary --region=us-central1
kubectl apply --dry-run=server -f app-a.yaml
kubectl apply --dry-run=server -f app-b.yaml
kubectl apply --dry-run=server -f primary-services.yaml
kubectl apply -f app-a.yaml
kubectl apply -f app-b.yaml
kubectl apply -f primary-services.yaml
```

Secondary:

```powershell
gcloud container clusters get-credentials gke-secondary --region=us-east1
kubectl apply --dry-run=server -f app-a.yaml
kubectl apply --dry-run=server -f app-b.yaml
kubectl apply -f app-a.yaml
kubectl apply -f app-b.yaml
```

## Operational Checks

Check rollout status:

```powershell
kubectl rollout status deployment/app-a
kubectl rollout status deployment/app-b
```

Check autoscaling:

```powershell
kubectl get hpa
kubectl describe hpa app-a
kubectl describe hpa app-b
```

Check application logs:

```powershell
kubectl logs deployment/app-a --tail=50
kubectl logs deployment/app-b --tail=50
```

On the primary cluster, find the public endpoints:

```powershell
kubectl get service app-a-service
kubectl get service app-b-service
```

## Safety Notes

- Always run `kubectl config current-context` before an apply operation.
- Use `--dry-run=server` before applying changed manifests.
- Apply `primary-services.yaml` only while connected to `gke-primary`.
- The secondary cluster receives App A, App B, and their HPAs, but no independent public LoadBalancer Services from these manifests.
- A production multi-cluster design can place a global traffic-management layer in front of both clusters instead of exposing each cluster independently.
