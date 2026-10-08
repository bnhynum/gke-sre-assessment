# Troubleshooting

This document records real issues encountered while implementing the GKE SRE assessment and the steps used to diagnose and resolve them. These examples are preserved as implementation evidence rather than presenting the environment as if it worked without iteration.

## Primary Troubleshooting Scenario: Terraform Could Not Authenticate

### Symptom

Terraform validation succeeded locally, but importing the existing GCP VPC failed with an authentication error indicating that Application Default Credentials could not be found.

The failure occurred when running an import similar to:

```powershell
terraform import google_compute_network.sre_vpc projects/project-19ae3503-8d3c-48b5-9d8/global/networks/sre-assessment-vpc
```

Terraform reported that neither provider credentials nor an access token had been configured and recommended Application Default Credentials.

### Initial State

The Google Cloud CLI was already authenticated and normal `gcloud` commands worked. This demonstrated that the problem was not general access to the assessment project.

### Diagnosis

The local workflow used two distinct authentication mechanisms:

```text
gcloud commands
    -> gcloud user authentication

Terraform Google provider
    -> Application Default Credentials
```

A check with:

```powershell
gcloud auth application-default print-access-token
```

confirmed that ADC had not yet been configured.

### Resolution

Application Default Credentials were established with:

```powershell
gcloud auth application-default login
```

After the browser authentication flow completed, the Terraform import was retried.

### Validation

The import then succeeded:

```text
Import successful!
```

Terraform state subsequently contained the imported VPC:

```powershell
terraform state list
```

and later the complete imported infrastructure.

After all resources were represented and reconciled, the final validation returned:

```text
No changes. Your infrastructure matches the configuration.
```

### Root Cause

Normal Google Cloud CLI authentication and local Application Default Credentials are separate credential mechanisms. The CLI was authenticated, but the Terraform Google provider had no ADC credentials available.

### Lesson Learned

For local Terraform workflows using the Google provider, validate both project configuration and ADC before beginning imports or plan operations.

Recommended checks:

```powershell
gcloud config get-value project
gcloud auth application-default print-access-token
```

Do not record or commit the printed token.

---

## Troubleshooting Scenario 2: kubectl Authentication Plugin Missing

### Symptom

The primary GKE cluster was created successfully, but the cluster creation output warned that continued kubectl access required `gke-gcloud-auth-plugin`, which was not found or executable.

The cluster itself showed a healthy status, so the warning was isolated to the local Kubernetes client authentication path rather than cluster creation.

### Diagnosis

The environment had a functioning Google Cloud CLI, but the local Kubernetes client dependencies required for authenticated GKE access were incomplete.

### Resolution

The required local Kubernetes client and GKE authentication plugin were installed through the Google Cloud SDK component tooling, and cluster credentials were refreshed:

```powershell
gcloud container clusters get-credentials gke-primary --region=us-central1
```

### Validation

The final test was:

```powershell
kubectl get nodes
```

Both primary cluster nodes returned `Ready`, proving successful local authenticated access.

### Lesson Learned

Separate cluster health from client-access health. A successfully provisioned GKE control plane does not guarantee the workstation has all client authentication components required by kubectl.

---

## Troubleshooting Scenario 3: BigQuery Dataset IAM Command Required Allowlisting

### Symptom

The Cloud Logging sink existed and pointed to the correct BigQuery dataset, but the attempted dataset-level IAM command returned:

```text
This feature requires allowlisting.
```

The command path used was based on `bq add-iam-policy-binding`.

### Diagnosis

The failure was specific to that dataset-level CLI capability in the assessment environment. The BigQuery API itself was enabled, the `gke_observability` dataset existed, and the Logging sink configuration could be described successfully.

The sink writer identity was obtained with:

```powershell
gcloud logging sinks describe gke-logs-to-bigquery
```

### Resolution

A project-level IAM binding was used for the Logging sink writer identity in this assessment environment.

This was broader than the preferred dataset-level scope but allowed validation to continue when the narrower CLI operation was unavailable.

### Validation

After permissions were available and fresh logs were generated, BigQuery reported exported tables:

```text
stderr_20261006
stdout_20261006
```

A live SQL query successfully returned GKE log records.

### Lesson Learned

Prefer least privilege, but distinguish an IAM design problem from a tooling/environment limitation. When a narrower operation is unavailable, document the deviation and the production-preferred approach.

### Production Recommendation

Use the narrowest supported BigQuery dataset or project scope permitted by organizational IAM policy and tooling.

---

## Troubleshooting Scenario 4: hello-app Did Not Contain wget

### Symptom

Fresh application traffic was needed to validate log export. An attempt to run:

```powershell
kubectl exec POD_NAME -- wget -qO- http://localhost:8080/
```

first failed because `POD_NAME` was a placeholder rather than an actual Pod name.

After substituting a real App B Pod, the command failed because the container image did not contain the `wget` executable.

### Diagnosis

The `hello-app` image is intentionally small and did not provide the local utility that the initial traffic-generation approach assumed.

The application itself was healthy, so modifying the image merely to add a debugging utility would have introduced unnecessary change.

### Resolution

Kubernetes port forwarding was used instead:

```powershell
kubectl port-forward deployment/app-b 8080:8080
```

From a second terminal, requests could then be sent from the workstation:

```powershell
curl http://localhost:8080
```

### Validation

The application returned its normal response, and the requests generated fresh log activity without adding packages to or modifying the application image.

### Lesson Learned

Do not assume diagnostic utilities exist inside minimal containers. Prefer non-invasive Kubernetes debugging techniques such as port forwarding when they satisfy the validation need.

---

## Troubleshooting Scenario 5: Kubernetes YAML Parsing Error

### Symptom

A server-side dry run of `app-a.yaml` partially processed the Deployment and Service but then failed with a YAML parsing error similar to:

```text
error converting YAML to JSON: yaml: line 22: found character that cannot start any token
```

`app-b.yaml` passed its server-side dry run.

### Diagnosis

Because Kubernetes had already recognized earlier resources in the file, the issue was isolated to local YAML formatting later in `app-a.yaml`, not to the cluster or general kubectl access.

Potential formatting causes included malformed indentation or a tab character introduced while editing.

### Resolution Approach

Inspect the YAML with line numbers:

```powershell
$i=1; Get-Content .\app-a.yaml | ForEach-Object { "{0,3}: {1}" -f $i++, $_ }
```

Search explicitly for tab characters:

```powershell
Select-String -Path .\app-a.yaml -Pattern "`t"
```

Replace tabs or malformed indentation with spaces and retry:

```powershell
kubectl apply --dry-run=server -f app-a.yaml
```

### Design Improvement

The manifests were also reorganized so common Deployments/HPAs remained in `app-a.yaml` and `app-b.yaml`, while primary-only public `LoadBalancer` Services were moved to `primary-services.yaml`.

This reduces both YAML complexity and the chance of accidentally creating public Services in the DR cluster.

### Lesson Learned

Use server-side dry runs before real applies. They can detect syntax/schema problems and cluster-specific resource behavior without persisting changes.

---

## Troubleshooting Scenario 6: Logging Severity Did Not Equal Application Failure

### Symptom

Cloud Logging and BigQuery showed records such as:

```text
severity: ERROR
textPayload: Serving request: /
```

At the same time, direct HTTP testing of App B successfully returned:

```text
Hello, world!
```

### Diagnosis

The sample application wrote successful request messages to stderr. Exported log severity was therefore influenced by the output stream rather than representing a verified failed customer request.

### Resolution

BigQuery application-activity queries were scoped using Kubernetes workload metadata and message content, for example:

```sql
WHERE resource.labels.container_name = 'hello-app'
  AND textPayload LIKE '%Serving request:%'
```

The assessment documentation explicitly avoids defining true application error rate as a count of all `ERROR`-severity records.

### Validation

BigQuery queries successfully showed `hello-app` activity from both `gke-primary` and `gke-secondary`.

### Lesson Learned

Validate logging semantics before deriving SRE metrics. A severity field is only useful as an error-rate signal when the application's logging behavior supports that interpretation.

### Production Recommendation

Use structured application logs containing trustworthy fields such as HTTP status code, explicit error type, exception state, or another reliable request outcome indicator.

---

## Troubleshooting Scenario 7: Logging Sink Already Existed

### Symptom

An attempt to create the Logging sink returned a conflict indicating:

```text
Sink gke-logs-to-bigquery already exists
```

### Diagnosis

This indicated an existing resource rather than a broken sink.

### Resolution

The existing sink was inspected rather than deleted or recreated:

```powershell
gcloud logging sinks describe gke-logs-to-bigquery
```

The output verified the expected destination, Kubernetes container filter, and writer identity.

### Lesson Learned

When an infrastructure command reports a name conflict, inspect the existing resource before changing or deleting anything. Reuse a correctly configured resource instead of treating existence as failure.

---

## Operational Troubleshooting Pattern Used

Across these issues, the implementation followed a consistent pattern:

```text
1. Preserve the exact error.
2. Identify whether the failure is local, Kubernetes, GCP service, IAM, or data-related.
3. Inspect current state before changing resources.
4. Make the smallest necessary change.
5. Re-run a specific validation command.
6. Preserve the result as assessment evidence.
```

Examples of focused validation commands included:

```powershell
kubectl get nodes
kubectl get pods -o wide
kubectl get hpa
gcloud logging sinks describe gke-logs-to-bigquery
bq ls project-19ae3503-8d3c-48b5-9d8:gke_observability
terraform state list
terraform plan
```

## Recommended Primary Scenario for the Assessment

The **Terraform Application Default Credentials issue** is a strong primary troubleshooting scenario because it has a clear symptom, root cause, corrective action, and final validation result.

A concise assessment summary can be written as:

> Terraform initially failed to import existing GCP resources because the Google provider could not find Application Default Credentials. Although the Google Cloud CLI was already authenticated, Terraform's local provider authentication required a separate ADC configuration. I confirmed ADC was missing, completed `gcloud auth application-default login`, retried the import successfully, imported the remaining validated resources, and verified the end state with a Terraform plan showing no changes.

Supporting evidence:

```text
Initial Terraform ADC error
Import successful!
terraform state list
No changes. Your infrastructure matches the configuration.
```

## Secondary Scenario Option

The **kubectl authentication-plugin issue** is another concise option:

> GKE cluster creation succeeded, but local kubectl access reported that the GKE authentication plugin was unavailable. I treated cluster health and client authentication as separate concerns, installed the required local client/plugin tooling, refreshed cluster credentials, and validated resolution when `kubectl get nodes` returned Ready nodes.

## Troubleshooting Scenario 8: Grafana BigQuery Authentication Under GCP Security Policy

### Symptom

Grafana OSS was installed locally on Windows to visualize GKE logs exported to BigQuery. The Google BigQuery data source installed successfully, but authentication initially failed.

The first approach used a dedicated Google service account:

    grafana-bigquery-reader

When a JSON key was requested, Google Cloud rejected the operation because the project enforced:

    constraints/iam.disableServiceAccountKeyCreation

The key creation attempt returned:

    FAILED_PRECONDITION: Key creation is not allowed on this service account.

### Security Decision

The organization policy was preserved rather than disabled.

Instead of weakening the project security configuration or creating another long-lived credential, the Grafana integration was redirected toward keyless authentication.

### Attempt 1: Local Application Default Credentials

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

### Diagnosis

The successful Application Default Credentials test demonstrated that Google credentials existed for the Windows user, but Grafana's GCE-oriented authentication mode did not successfully consume the local workstation credential configuration.

The problem was therefore not BigQuery availability or general Google Cloud authentication. The authentication model being used by the Grafana BigQuery plugin did not fit the local Windows deployment.

Rather than continue modifying the workstation, IAM configuration, or organization security policy for an unsuitable authentication method, the GCE authentication path was abandoned.

### Resolution: Google OAuth with Forward OAuth Identity

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

### Validation

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

### Root Cause

The authentication problem resulted from a combination of security policy and authentication-method compatibility.

Two approaches proved unsuitable:

1. Long-lived service-account JSON keys were prohibited by the GCP project's organization policy.
2. Grafana's GCE Default Service Account mode did not successfully discover the Windows workstation's local Application Default Credentials.

Google OAuth with Forward OAuth Identity provided a working keyless authentication model that matched the local Grafana deployment while preserving the existing GCP security restriction.

### Lessons Learned

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

### Observability Lesson

The Grafana implementation also reinforced an earlier logging observation.

The `hello-app` sample writes successful:

    Serving request: /

messages to stderr. These records can therefore appear with `ERROR` severity even when the HTTP request succeeds.

As a result, the dashboard does not present all `ERROR`-severity records as application failures.

The implemented Grafana panels visualize metrics directly supported by the exported data, including request activity and log volume.

True application error rate, latency percentiles, restart rates, and CPU/memory utilization require appropriate structured application telemetry or Kubernetes/Cloud Monitoring metric sources and are not fabricated from log fields that do not contain those measurements.

### Repository Security

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

### Assessment Value

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

## Related Documentation

```text
../README.md
setup.md
design-decisions.md
../terraform/README.md
../kubernetes/README.md
../queries/README.md
```
