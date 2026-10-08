# Grafana BigQuery Authentication Troubleshooting

This document captures the authentication issue encountered while connecting local Grafana OSS to the GKE SRE assessment BigQuery dataset, the approaches tested, and the final keyless solution.

## Scenario

Grafana OSS was installed locally on Windows to visualize GKE logs exported to BigQuery. The Google BigQuery data source installed successfully, but authentication initially failed.

The target data source was:

    GCP project: project-19ae3503-8d3c-48b5-9d8
    BigQuery dataset: gke_observability

## Symptom

The first approach used a dedicated Google service account:

    grafana-bigquery-reader

When a JSON key was requested, Google Cloud rejected the operation because the project enforced:

    constraints/iam.disableServiceAccountKeyCreation

The key creation attempt returned:

    FAILED_PRECONDITION: Key creation is not allowed on this service account.

## Security Decision

The organization policy was preserved rather than disabled.

Instead of weakening the project security configuration or creating another long-lived credential, the Grafana integration was redirected toward keyless authentication.

## Attempt 1: Local Application Default Credentials

The workstation already had working Google Application Default Credentials from the Terraform implementation.

Grafana initially ran as the Windows:

    LocalSystem

account, while the workstation Application Default Credentials belonged to the interactive Windows user.

The Grafana Windows service was changed to run under:

    .\sever

Application Default Credentials were then verified under the same Windows account.

The `GOOGLE_APPLICATION_CREDENTIALS` environment variable was also configured to reference the local Application Default Credentials file, and the Grafana service was restarted.

However, the BigQuery plugin's **GCE Default Service Account** authentication mode continued returning:

    failed to retrieve google access token:
    google: could not find default credentials

## Diagnosis

The successful Application Default Credentials test demonstrated that Google credentials existed for the Windows user, but Grafana's GCE-oriented authentication mode did not successfully consume the local workstation credential configuration.

The problem was therefore not BigQuery availability or general Google Cloud authentication. The authentication model being used by the Grafana BigQuery plugin did not fit the local Windows deployment.

Rather than continue modifying the workstation, IAM configuration, or organization security policy for an unsuitable authentication method, the GCE authentication path was abandoned.

## Resolution: Google OAuth with Forward OAuth Identity

Grafana was reconfigured to use Google OAuth.

A separate Grafana configuration file was created at:

    C:\Program Files\GrafanaLabs\grafana\conf\custom.ini

rather than modifying Grafana's default configuration.

Google OAuth was enabled and configured to request normal identity scopes plus BigQuery authorization.

A Google OAuth 2.0 Web application client was created with the local Grafana callback:

    http://localhost:3000/login/google

The OAuth application remained in Google's **Testing** mode.

An initial Google login attempt was rejected because only developer-approved test users could access the application. The assessment Google account was then added to the OAuth application's approved test users.

Grafana login through Google OAuth subsequently succeeded.

The Grafana BigQuery data source was configured with:

    Authentication:       Forward OAuth Identity
    Default project:      project-19ae3503-8d3c-48b5-9d8
    Processing location:  United States (US)

Long-lived Google service-account private keys were not required.

## Validation

The Grafana BigQuery data source successfully passed its connection test.

Grafana then queried the existing:

    gke_observability

BigQuery dataset containing the GKE logs exported through Cloud Logging.

A working four-panel dashboard named:

    GKE SRE Assessment Observability

was created using the exported GKE data.

The dashboard contains:

1. **Application Request Activity by Cluster**: time-series visualization of `hello-app` activity across `gke-primary` and `gke-secondary`.
2. **Requests by Cluster**: bar-chart comparison of aggregate `hello-app` request-log activity by cluster.
3. **Log Volume Over Time**: time-series visualization of exported GKE stderr log volume.
4. **Log Volume by Cluster**: bar-chart comparison of overall exported stderr log volume by cluster.

The validated observability path is:

    gke-primary + gke-secondary
              |
              v
         Cloud Logging
              |
              v
          Log Router
     gke-logs-to-bigquery
              |
              v
           BigQuery
       gke_observability
              |
              v
         Google OAuth
              |
              v
     Forward OAuth Identity
              |
              v
            Grafana

## Root Cause

The authentication problem resulted from a combination of security policy and authentication-method compatibility.

Two approaches proved unsuitable:

1. Long-lived service-account JSON keys were prohibited by the GCP project's organization policy.
2. Grafana's GCE Default Service Account mode did not successfully discover the Windows workstation's local Application Default Credentials.

Google OAuth with Forward OAuth Identity provided a working keyless authentication model that matched the local Grafana deployment while preserving the existing GCP security restriction.

## Lessons Learned

Authentication design should match both the hosting environment and the organization's security controls.

A blocked service-account key should not automatically be treated as a policy that needs to be disabled. In this case, preserving the existing security control led to a keyless OAuth solution using delegated credentials.

The troubleshooting path was:

    Service-account key blocked
            |
            v
    Preserve security policy
            |
            v
    Test workstation ADC
            |
            v
    Identify GCE/local authentication mismatch
            |
            v
    Configure Google OAuth
            |
            v
    Authorize assessment test user
            |
            v
    Use Forward OAuth Identity
            |
            v
    Validate BigQuery connection
            |
            v
    Build working Grafana dashboard

The experience also reinforced the importance of distinguishing between:

    Google Cloud CLI authentication
    Application Default Credentials
    GCE service-account authentication
    Google OAuth delegated identity

Each mechanism serves a different authentication context.

## Observability Lesson

The Grafana implementation also reinforced an earlier logging observation.

The `hello-app` sample writes successful:

    Serving request: /

messages to stderr. These records can therefore appear with `ERROR` severity even when the HTTP request succeeds.

As a result, the dashboard does not present all `ERROR`-severity records as application failures.

The implemented Grafana panels visualize metrics directly supported by the exported data, including request activity and log volume.

True application error rate, latency percentiles, restart rates, and CPU/memory utilization require appropriate structured application telemetry or Kubernetes/Cloud Monitoring metric sources and are not fabricated from log fields that do not contain those measurements.

## Repository Security

Credential material must not be committed to the assessment repository.

This includes:

    Google OAuth client secrets
    Application Default Credential files
    Google access tokens
    Service-account private keys
    Grafana authentication secrets

Only non-secret documentation, queries, Infrastructure as Code, Kubernetes configuration, screenshots, and exported Grafana dashboard definitions should be stored with the assessment artifacts.

The Grafana dashboard definition can be stored under:

    grafana/
    └── gke-sre-observability-dashboard.json

## Assessment Value

This troubleshooting scenario demonstrates several SRE and platform-engineering practices:

- Preserving an enforced cloud security control rather than weakening it
- Diagnosing authentication across Windows services, Grafana, and Google Cloud
- Distinguishing user ADC from GCE service-account authentication
- Moving away from long-lived credentials
- Implementing OAuth-based delegated access
- Troubleshooting OAuth test-user restrictions
- Validating authentication against live BigQuery data
- Building an end-to-end observability pipeline
- Keeping secrets outside the Infrastructure as Code repository
- Making dashboard claims only from telemetry actually present in the data

The final result preserved the GCP project's service-account-key restriction while still delivering a working Grafana dashboard backed by live GKE observability data.
