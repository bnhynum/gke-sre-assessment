# GKE SRE Assessment Architecture

```mermaid
flowchart TB
  Internet[Customer / Internet]
  PublicLB[Primary Public LoadBalancer Services\nApp A + App B]

  subgraph VPC[sre-assessment-vpc]
    direction LR

    subgraph PRIMARY[Primary Region: us-central1]
      direction TB
      PSubnet[gke-primary-subnet\nNodes: 10.10.0.0/20\nPods: 10.20.0.0/16\nServices: 10.30.0.0/20]
      PCluster[gke-primary\nGKE Standard\nRegular release channel\ne2-standard-2\nNode autoscaling: 1-3]
      PA[App A\nnginx:1.27\n2+ Pods\nHPA: 2-5 at 60% CPU]
      PB[App B\nhello-app:1.0\n2+ Pods\nHPA: 2-5 at 60% CPU]
      PSubnet --> PCluster
      PCluster --> PA
      PCluster --> PB
    end

    subgraph SECONDARY[Secondary / DR Region: us-east1]
      direction TB
      SSubnet[gke-secondary-subnet\nNodes: 10.40.0.0/20\nPods: 10.50.0.0/16\nServices: 10.60.0.0/20]
      SCluster[gke-secondary\nGKE Standard\nRegular release channel\ne2-standard-2\nNode autoscaling: 1-3]
      SA[App A\nnginx:1.27\n2+ Pods\nHPA: 2-5 at 60% CPU]
      SB[App B\nhello-app:1.0\n2+ Pods\nHPA: 2-5 at 60% CPU]
      SSubnet --> SCluster
      SCluster --> SA
      SCluster --> SB
    end
  end

  Internet --> PublicLB
  PublicLB --> PA
  PublicLB --> PB

  PA --> Logging[Cloud Logging\nGKE system + workload logs]
  PB --> Logging
  SA --> Logging
  SB --> Logging
  Logging --> Sink[Log Router Sink\ngke-logs-to-bigquery\nresource.type=k8s_container]
  Sink --> BQ[BigQuery\ngke_observability\nstderr / stdout log tables]

  Terraform[Terraform\nVPC + subnets + GKE + BigQuery + sink\nFinal plan: No changes] -. manages .-> PSubnet
  Terraform -. manages .-> SSubnet
  Terraform -. manages .-> PCluster
  Terraform -. manages .-> SCluster
  Terraform -. manages .-> Sink
  Terraform -. manages .-> BQ

  Production[Documented production evolution\nCloud DNS -> Global HTTPS LB -> Cloud Armor\n-> Multi-cluster ingress/services -> both clusters]
  Production -. future .-> PCluster
  Production -. future .-> SCluster
```

## Legend

- Solid lines show implemented traffic, workload, or logging relationships.
- Dashed Terraform lines show infrastructure represented and managed through Terraform.
- The production-evolution block is architectural intent, not claimed as implemented assessment infrastructure.
