-- GKE SRE Assessment: BigQuery Observability Queries
-- Project: project-19ae3503-8d3c-48b5-9d8
-- Dataset: gke_observability
-- Validated export tables for this assessment date:
--   stderr_20261006
--   stdout_20261006
--
-- Note: hello-app writes successful "Serving request: /" messages to stderr.
-- Do not interpret all ERROR-severity rows as application failures.

-- ============================================================================
-- Query 1: Recent container log records
-- Purpose: Validate that exported GKE container logs are queryable in BigQuery.
-- ============================================================================
SELECT
  timestamp,
  severity,
  textPayload
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006`
ORDER BY timestamp DESC
LIMIT 10;

-- ============================================================================
-- Query 2: Log volume over time
-- Purpose: Minute-level time series suitable for activity/trend visualization.
-- ============================================================================
SELECT
  TIMESTAMP_TRUNC(timestamp, MINUTE) AS minute,
  COUNT(*) AS log_count
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006`
GROUP BY minute
ORDER BY minute;

-- ============================================================================
-- Query 3: Application activity by cluster
-- Purpose: Compare hello-app activity between the primary and secondary GKE
-- clusters while excluding unrelated GKE system containers.
-- ============================================================================
SELECT
  resource.labels.cluster_name AS cluster,
  COUNT(*) AS log_count
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006`
WHERE resource.labels.container_name = 'hello-app'
GROUP BY cluster
ORDER BY log_count DESC;

-- ============================================================================
-- Query 4: Request traffic over time by cluster
-- Purpose: Dashboard-ready request activity time series for hello-app.
-- Uses message content because successful requests are written to stderr.
-- ============================================================================
SELECT
  TIMESTAMP_TRUNC(timestamp, MINUTE) AS time,
  resource.labels.cluster_name AS cluster,
  COUNT(*) AS request_count
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006`
WHERE resource.labels.container_name = 'hello-app'
  AND textPayload LIKE '%Serving request:%'
GROUP BY time, cluster
ORDER BY time;

-- ============================================================================
-- Query 5: Container log volume by cluster and container
-- Purpose: Identify application and GKE system containers contributing records
-- to the exported stderr table.
-- ============================================================================
SELECT
  resource.labels.cluster_name AS cluster,
  resource.labels.container_name AS container,
  COUNT(*) AS log_count
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006`
GROUP BY cluster, container
ORDER BY log_count DESC;

-- ============================================================================
-- Query 6: Recent hello-app request records with Kubernetes dimensions
-- Purpose: Inspect which cluster, namespace, pod, and container produced each
-- recent application request record.
-- ============================================================================
SELECT
  timestamp,
  resource.labels.cluster_name AS cluster,
  resource.labels.namespace_name AS namespace,
  resource.labels.pod_name AS pod,
  resource.labels.container_name AS container,
  severity,
  textPayload
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006`
WHERE resource.labels.container_name = 'hello-app'
  AND textPayload LIKE '%Serving request:%'
ORDER BY timestamp DESC
LIMIT 50;

-- ============================================================================
-- Query 7: Request distribution by pod
-- Purpose: Show request-log activity across hello-app replicas in each cluster.
-- This measures log/request distribution, not latency or success rate.
-- ============================================================================
SELECT
  resource.labels.cluster_name AS cluster,
  resource.labels.pod_name AS pod,
  COUNT(*) AS request_count
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stderr_20261006`
WHERE resource.labels.container_name = 'hello-app'
  AND textPayload LIKE '%Serving request:%'
GROUP BY cluster, pod
ORDER BY cluster, request_count DESC;

-- ============================================================================
-- Query 8: stdout log volume by cluster and container
-- Purpose: Inspect the separate stdout export table for workload/system output.
-- ============================================================================
SELECT
  resource.labels.cluster_name AS cluster,
  resource.labels.container_name AS container,
  COUNT(*) AS log_count
FROM `project-19ae3503-8d3c-48b5-9d8.gke_observability.stdout_20261006`
GROUP BY cluster, container
ORDER BY log_count DESC;

-- ============================================================================
-- IMPORTANT ANALYSIS NOTE
-- ============================================================================
-- The validated hello-app records demonstrate that a successful HTTP request can
-- appear in the stderr table with severity=ERROR because of the stream used by
-- the sample application. Therefore a production-quality application error-rate
-- query requires a reliable failure signal such as structured HTTP status,
-- exception/error type, or another application-level success/failure field.
-- No query in this file claims that COUNTIF(severity='ERROR') is a true
-- application error rate.
--
-- The assessment also discusses pod restarts, request latency percentiles, and
-- CPU/memory utilization. Those metrics are not fabricated here from log fields
-- that were not validated. They should be sourced from appropriate Kubernetes or
-- Cloud Monitoring metrics when available.
