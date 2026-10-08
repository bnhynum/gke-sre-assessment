# IAM Design

## Purpose

This document defines the target IAM model for the GKE SRE assessment.

The design separates human and automation access into four personas:

- Developers
- Operations
- SRE
- CI/CD

The goal is to demonstrate least privilege, separation of duties, group-based human access, and dedicated non-human identities for deployment automation.

## Assessment Environment

GCP project:

    project-19ae3503-8d3c-48b5-9d8

Project name:

    CS SRE Assessment

The supplied assessment project is located directly beneath the GCP organization rather than beneath an intermediary folder.

Current hierarchy:

    Organization
        |
        v
    CS SRE Assessment Project

Target enterprise landing-zone pattern:

    Organization
        |
        v
    Environment / Application Folder
        |
        v
    CS SRE Assessment Project

The existing project hierarchy was preserved because changing organization-level resource placement was outside the scope of the assessment implementation.

## IAM Principles

The IAM design follows these principles:

1. Grant access to groups rather than individual users where possible.
2. Use dedicated workload identities for automation.
3. Separate application-development access from platform administration.
4. Separate CI/CD identities from human identities.
5. Prefer read-only access unless write privileges are required.
6. Avoid broad primitive roles such as Owner and Editor for routine operations.
7. Use Workload Identity or federated identity for automation rather than long-lived service-account keys.
8. Keep production credentials outside source control.
9. Treat administrative privileges as exceptional rather than normal operating access.

## Identity Model

The target identity model is:

    Human users
         |
         +----------------+----------------+----------------+
         |                |                |
         v                v                v
    Developers        Operations          SRE
       Group             Group            Group

                           +

                    CI/CD Workload
                       Identity
                           |
                           v
                   Deployment Pipeline

Human access should normally be assigned through organization-managed Google Groups or the organization's identity provider.

CI/CD should use a dedicated machine identity rather than a human account.

## Persona 1: Developers

### Purpose

Developers build, deploy, inspect, and troubleshoot application workloads without administering the underlying GCP project.

### Responsibilities

Developers may require the ability to:

- inspect application workloads
- inspect Kubernetes configuration
- deploy approved application changes
- inspect application logs
- review application-level monitoring data
- troubleshoot application behavior

### Access Boundary

Developers should not normally:

- administer project IAM
- modify the VPC
- create or delete GKE clusters
- modify organization policies
- administer BigQuery infrastructure
- change logging sinks
- manage production secrets directly

### Recommended Access Pattern

Suggested GCP/Kubernetes access should be limited to the application responsibilities actually required by the environment.

Typical access areas include:

    Kubernetes workload access
    Cloud Logging read access
    Cloud Monitoring read access

Kubernetes RBAC should provide the final in-cluster authorization boundary.

For example:

    Developer identity
          |
          v
    GCP authentication
          |
          v
    Kubernetes RBAC
          |
          +-- Deployment read/update
          +-- Pod read
          +-- Service read
          +-- ConfigMap access as required
          +-- application namespace only

Namespace-scoped Kubernetes authorization is preferable to unrestricted cluster-admin access.

## Persona 2: Operations

### Purpose

Operations maintains the runtime platform and responds to infrastructure and cluster operational issues.

### Responsibilities

Operations may require the ability to:

- inspect GKE cluster health
- inspect node and workload status
- perform approved cluster operations
- inspect networking behavior
- review Cloud Logging
- review Cloud Monitoring
- investigate runtime incidents
- support service availability

### Access Boundary

Operations should not automatically receive:

- organization administration
- project IAM administration
- unrestricted application-development access
- unrestricted BigQuery administration
- unrestricted service-account administration

### Recommended Access Pattern

Operations access generally includes:

    GKE operational access
    Cloud Logging viewing
    Cloud Monitoring viewing
    Compute/network viewing

Write permissions should only be granted where operational changes are part of the team's responsibilities.

## Persona 3: SRE

### Purpose

SRE owns reliability, observability, operational readiness, incident analysis, and platform health.

### Responsibilities

SRE may require the ability to:

- inspect and operate GKE clusters
- inspect workloads and nodes
- review application and infrastructure logs
- review Cloud Monitoring data
- use Managed Service for Prometheus
- investigate scaling behavior
- troubleshoot network and service availability
- analyze BigQuery observability exports
- develop monitoring and reliability controls

The assessment environment currently enables:

    Cloud Logging
      - SYSTEM_COMPONENTS
      - WORKLOADS

    Cloud Monitoring
      - SYSTEM_COMPONENTS

    Managed Prometheus
      - enabled

### Access Boundary

SRE should not automatically receive:

- organization-level administration
- billing administration
- unrestricted project IAM administration
- application source-code administration
- long-lived service-account private keys

### Recommended Access Pattern

SRE access generally includes:

    GKE operational access
    Cloud Logging access
    Cloud Monitoring access
    observability BigQuery read/query access

The SRE role is intentionally broader than developer visibility but remains separate from project IAM administration.

## Persona 4: CI/CD

### Purpose

CI/CD is a non-human deployment identity used by automated pipelines.

The assessment repository is intended to support automated infrastructure and Kubernetes deployment workflows.

### Responsibilities

A CI/CD identity may require the ability to:

- authenticate to GCP
- deploy approved Kubernetes manifests
- deploy approved infrastructure changes
- access required artifact repositories
- update allowed application workloads
- execute deployment validation
- read only the metadata required by the pipeline

### Identity Model

Preferred:

    GitHub Actions
         |
         v
    Federated / short-lived identity
         |
         v
    Dedicated GCP deployment identity
         |
         v
    Approved GCP + GKE operations

Avoid:

    GitHub Actions
         |
         v
    Long-lived JSON service-account key

The assessment project already demonstrated an organization policy that prevents service-account key creation. The IAM architecture preserves that control rather than weakening it.

### Separation of Duties

Infrastructure and application deployment can be further separated if required:

    CI/CD Infrastructure Identity
        |
        +-- Terraform-controlled infrastructure

    CI/CD Application Identity
        |
        +-- Kubernetes workload deployment

This prevents an application deployment pipeline from automatically receiving infrastructure-administration privileges.

## Human vs. Machine Access

Human personas:

    Developers
    Operations
    SRE

should normally authenticate through organization-managed user identities and groups.

Automation:

    CI/CD

should use a dedicated non-human identity.

Human credentials should not be embedded into automation.

Machine credentials should not be shared with human users.

## Current Assessment IAM State

The project contains the assessment owner identity along with Google-managed service identities and purpose-specific identities created during implementation.

The assessment owner's broad access was used to provision and configure the isolated assessment environment.

This should not be treated as the recommended production access model.

Production environments should replace routine individual Owner access with group-based, least-privilege access and controlled privileged administration.

## Target Enterprise IAM Structure

Conceptually:

    GCP Organization
          |
          v
    Application / Environment Folder
          |
          v
    Project
          |
          +---------------- Developers Group
          |
          +---------------- Operations Group
          |
          +---------------- SRE Group
          |
          +---------------- CI/CD Workload Identity
          |
          +---------------- Google-managed service agents

The human groups would normally be managed by the organization's identity platform rather than created as assessment-only fake identities.

## Recommended Role Matrix

The following matrix describes responsibilities rather than asserting that these identities currently exist.

| Capability | Developers | Operations | SRE | CI/CD |
|---|---:|---:|---:|---:|
| View application workloads | Yes | Yes | Yes | As required |
| Deploy application workloads | As approved | Limited | Limited | Yes |
| View GKE cluster health | Yes | Yes | Yes | As required |
| Administer GKE infrastructure | No | As required | As required | Terraform pipeline only |
| View Cloud Logging | Yes | Yes | Yes | Limited |
| View Cloud Monitoring | Yes | Yes | Yes | Limited |
| Query observability BigQuery data | Optional | Optional | Yes | No |
| Modify VPC | No | Restricted | Restricted | Infrastructure pipeline only |
| Modify IAM | No | No | No | No |
| Manage organization policy | No | No | No | No |
| Use long-lived service-account keys | No | No | No | No |

"Yes" means the persona's responsibilities justify the capability. The exact Google IAM predefined roles should be validated against current Google Cloud documentation and organizational policy before production assignment.

## Kubernetes RBAC

GCP IAM controls access to Google Cloud resources, but Kubernetes RBAC should provide additional authorization inside the clusters.

Suggested logical boundaries:

    Developers
        -> application namespace permissions

    Operations
        -> cluster operational permissions

    SRE
        -> reliability and troubleshooting permissions

    CI/CD
        -> specifically authorized deployment permissions

Avoid assigning:

    cluster-admin

to every user or automation identity.

## BigQuery Access

The assessment observability pipeline is:

    GKE
      |
      v
    Cloud Logging
      |
      v
    Log Router
      |
      v
    BigQuery
      |
      v
    Grafana

BigQuery authorization should distinguish between:

    Logging writer identity
        -> writes exported logs

    SRE / authorized analysts
        -> reads and queries observability data

    Grafana delegated user identity
        -> executes dashboard queries

These responsibilities should remain separated.

## Grafana Authentication

The assessment originally evaluated a dedicated Grafana service account.

Service-account key creation was blocked by:

    constraints/iam.disableServiceAccountKeyCreation

The security control was preserved.

The final Grafana architecture uses:

    Google OAuth
        |
        v
    Forward OAuth Identity
        |
        v
    BigQuery

This avoids introducing a long-lived Grafana service-account private key.

## Secrets and Credentials

The following must never be committed to the repository:

    Application Default Credential files
    OAuth client secrets
    OAuth access tokens
    OAuth refresh tokens
    service-account private keys
    kubeconfig credentials
    Grafana secrets

The repository should contain configuration and documentation only.

## Terraform Strategy

Only real identities that exist and are intentionally managed by the assessment should be represented as Terraform IAM bindings.

Do not create fake:

    Developer users
    Operations users
    SRE users
    Google Groups

solely to demonstrate IAM.

A production implementation would parameterize group identities through Terraform variables, for example:

    developer_group
    operations_group
    sre_group
    cicd_identity

This allows organization-managed identity values to be supplied without hard-coding individuals into the infrastructure configuration.

## Recommended Production Pattern

    Identity Provider
          |
          +----------------------+
          |                      |
          v                      v
    Human Groups           Workload Federation
          |                      |
          v                      v
      GCP IAM                CI/CD Identity
          |                      |
          +----------+-----------+
                     |
                     v
                GCP Project
                     |
       +-------------+-------------+
       |             |             |
       v             v             v
      GKE       Observability    Networking
       |
       v
    Kubernetes RBAC

## Assessment Implementation Decision

The four personas are implemented as an IAM design rather than fake users or groups because the supplied assessment environment does not provide organization-managed Dev, Ops, or SRE group identities.

The design therefore demonstrates:

- least-privilege access boundaries
- separation of duties
- human vs. machine identity separation
- group-based enterprise access
- CI/CD workload identity
- preservation of organization security policy
- Kubernetes RBAC as an additional authorization layer
- avoidance of long-lived service-account keys

## Future Production Enhancements

A production implementation should additionally evaluate:

- organization-managed Google Groups
- separate production and non-production projects
- folder-level inherited IAM
- privileged-access elevation
- IAM Conditions
- workload identity federation for GitHub Actions
- periodic IAM access reviews
- audit-log monitoring
- unused-role detection
- automated policy validation
- separate infrastructure and application CI/CD identities

## Summary

The IAM architecture separates responsibilities into four distinct personas:

    Developers
        -> application delivery and troubleshooting

    Operations
        -> platform operations

    SRE
        -> reliability and observability

    CI/CD
        -> automated deployment

