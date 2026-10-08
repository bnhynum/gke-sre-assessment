# BigQuery Observability Queries

This directory contains SQL queries used to analyze GKE container logs exported from Cloud Logging into BigQuery for the GKE SRE assessment.

## Data Pipeline

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
    |
    v
SQL analysis / dashboard-ready datasets
```

Project and dataset:

```text
Project: project-19ae3503-8d3c-48b5-9d8
Dataset: gke_observability
```

The validated export created daily tables including:

```text
stderr_20261006
stdout_20261006
```

## Files

```text
queries/
|-- README.md
`-- observability.sql
```

`observability.sql` should contain the assessment-ready queries documented below.

## Running Queries

Queries can be executed from the Google Cloud SDK using the BigQuery CLI.

Example:

```powershell
bq query --use_legacy_sql=false "SELECT timestamp, severity, textPayload FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006` ORDER BY timestamp DESC LIMIT 10"
```

Standard SQL is used for all queries in this directory.

## Query 1: Recent Container Log Records

Purpose: inspect recent exported log records and validate that the Cloud Logging to BigQuery pipeline is producing queryable data.

```sql
SELECT
  timestamp,
  severity,
  textPayload
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006`
ORDER BY timestamp DESC
LIMIT 10;
```

This query was validated against live exported data.

## Query 2: Log Volume Over Time

Purpose: create a time-series view of log volume that can be used for activity analysis or a dashboard panel.

```sql
SELECT
  TIMESTAMP_TRUNC(timestamp, MINUTE) AS minute,
  COUNT(*) AS log_count
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006`
GROUP BY minute
ORDER BY minute;
```

A validation run returned minute-level log counts from the exported GKE data.

## Query 3: Application Activity by Cluster

Purpose: compare App B log activity between the primary and secondary GKE clusters while excluding unrelated system containers.

```sql
SELECT
  resource.labels.cluster_name AS cluster,
  COUNT(*) AS log_count
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006`
WHERE resource.labels.container_name = 'hello-app'
GROUP BY cluster
ORDER BY log_count DESC;
```

A validation run confirmed `hello-app` records from both:

```text
gke-primary
gke-secondary
```

## Query 4: Request Traffic Over Time by Cluster

Purpose: create a dashboard-ready time series showing application request activity separately for each cluster.

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

This query uses both Kubernetes workload metadata and message content to isolate application request activity.

## Query 5: Container Log Volume by Cluster and Container

Purpose: understand which workloads and GKE system components contribute records to the exported stderr table.

```sql
SELECT
  resource.labels.cluster_name AS cluster,
  resource.labels.container_name AS container,
  COUNT(*) AS log_count
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006`
GROUP BY cluster, container
ORDER BY log_count DESC;
```

The validation run showed application records from `hello-app` as well as system components such as Kubernetes and GKE agents. This is why application dashboard queries should filter to the intended workload rather than aggregate the whole table indiscriminately.

## Important Severity Finding

The `hello-app` sample writes successful request messages such as:

```text
Serving request: /
```

to stderr. Exported records can therefore have:

```text
severity = ERROR
```

even when the HTTP request succeeded.

For this assessment, **do not define application error rate as a simple count of all `ERROR`-severity rows**. That would misclassify successful `hello-app` requests as failures.

A better production approach is to use application logs that contain explicit outcome fields such as HTTP status code, structured error type, exception status, or another reliable application-level success/failure signal. The current sample workload does not provide those fields in the validated request records.

## Dashboard Mapping

The assessment describes dashboard panels for error rate, restarts, latency percentiles, and resource utilization. The current BigQuery export has been validated for container log analysis and request/activity time series.

Suggested mapping for the implemented data:

| Panel | Query / Source | Assessment Status |
|---|---|---|
| Application activity over time | Query 4 | Validated |
| Log volume over time | Query 2 | Validated |
| Activity by cluster | Query 3 | Validated |
| Error rate | Requires reliable application failure signal | Not derived from severity alone |
| Pod restart counts | Better sourced from Kubernetes/monitoring metrics unless restart events are exported in a suitable log schema | Not implemented in these queries |
| p50/p95/p99 latency | Requires latency measurements | Not present in the validated sample request log payload |
| CPU/memory utilization | Better sourced from Cloud Monitoring / managed metrics | Not implemented in this BigQuery log query set |

The distinction is intentional: these queries only claim metrics demonstrated by the available exported data.

## Table Naming Note

The validated Logging sink produced daily tables such as:

```text
stderr_20261006
stdout_20261006
```

The date suffix is specific to the exported table used during the assessment. If running the queries against a different export date, update the table name accordingly.

To list the currently available tables:

```powershell
bq ls project-19ae3503-8d3c-48b5-9d8:gke_observability
```

## Inspecting the Schema

Use the real BigQuery schema before adding new queries:

```powershell
bq show --schema --format=prettyjson project-19ae3503-8d3c-48b5-9d8:gke_observability.stderr_20261006
```

This prevents assumptions about field names or nested resource labels.

## Useful Log Dimensions

The validated GKE export includes Kubernetes resource metadata useful for analysis, including fields such as:

```text
resource.labels.cluster_name
resource.labels.container_name
resource.labels.namespace_name
resource.labels.pod_name
```

These dimensions make it possible to scope queries to the intended cluster, workload, namespace, or pod.

## Assessment Evidence

Recommended evidence from this directory:

- Screenshot of Query 1 returning live log records
- Screenshot of Query 2 returning minute-level activity
- Screenshot or saved result showing `hello-app` records from both GKE clusters
- Copy of `observability.sql`
- Documentation of the stderr / `ERROR` severity finding

## Safety and Cost Notes

- Scope queries to the required tables and fields.
- Avoid repeatedly scanning unnecessary data.
- Use `LIMIT` for exploratory row-level queries.
- Filter to application containers when system logs are not relevant.
- Do not treat log severity as an application failure signal without validating application logging behavior.
- Do not include credentials, access tokens, or secrets in SQL files or query output committed to the repository.

## Related Documentation

See:

```text
../README.md
../terraform/README.md
../kubernetes/README.md
```

for the overall architecture, infrastructure configuration, and workload deployment procedures.
