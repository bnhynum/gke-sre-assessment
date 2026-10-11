# GKE SRE Assessment Architecture

```mermaid
flowchart TD

Internet[Internet Users]

GLB["Global External Load Balancer<br/>VIP: 136.68.145.210"]

MCI["Multi-Cluster Ingress (MCI)"]

MCS["Multi-Cluster Services (MCS)<br/>Fleet Membership"]

Primary["gke-primary<br/>us-central1"]

Secondary["gke-secondary<br/>us-east1"]

AppA1["App A<br/>2+ Replicas"]
AppA2["App A<br/>2+ Replicas"]

AppB1["App B<br/>2+ Replicas"]
AppB2["App B<br/>2+ Replicas"]

HC["Global Health Checks"]

NEG1["NEG<br/>us-central1-a"]
NEG2["NEG<br/>us-east1-b"]

Logging["Cloud Logging"]

Sink["Log Router Sink<br/>gke-logs-to-bigquery"]

BQ["BigQuery<br/>gke_observability"]

Grafana["Grafana Dashboard"]

Internet --> GLB
GLB --> MCI

MCI --> NEG1
MCI --> NEG2

HC --> NEG1
HC --> NEG2

NEG1 --> Primary
NEG2 --> Secondary

Primary --> AppA1
Primary --> AppB1

Secondary --> AppA2
Secondary --> AppB2

Primary <--> MCS
Secondary <--> MCS

AppA1 --> Logging
AppA2 --> Logging
AppB1 --> Logging
AppB2 --> Logging

Logging --> Sink
Sink --> BQ
BQ --> Grafana
```

## Legend

The production traffic path is implemented using Google Kubernetes Engine Multi-Cluster Services (MCS) and Multi-Cluster Ingress (MCI). A Global External Load Balancer exposes a single public VIP (136.68.145.210) and distributes traffic across healthy backend services deployed in both gke-primary (us-central1) and gke-secondary (us-east1).

Multi-Cluster Ingress automatically provisions regional Network Endpoint Groups (NEGs), backend services, forwarding rules, URL maps, target proxies, and health checks. Traffic is routed only to healthy backends, providing automatic cross-regional failover and high availability.

Application telemetry from both clusters is centralized through Cloud Logging, exported via the gke-logs-to-bigquery Log Router sink, stored in the gke_observability BigQuery dataset, and visualized through Grafana dashboards.

Evidence of implementation includes:
- Multi-Cluster Services ACTIVE
- Multi-Cluster Ingress ACTIVE
- Fleet memberships registered for both clusters
- ServiceExport and ServiceImport resources created
- Global VIP: 136.68.145.210
- Network Endpoint Groups provisioned in us-central1-a and us-east1-b
- Health-check-based global traffic routing
