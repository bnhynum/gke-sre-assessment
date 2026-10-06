resource "google_bigquery_dataset" "gke_observability" {
  dataset_id = "gke_observability"
  project    = var.project_id
  location   = "US"

  description = "GKE observability logs exported from Cloud Logging"
}

resource "google_logging_project_sink" "gke_logs_to_bigquery" {
  name    = "gke-logs-to-bigquery"
  project = var.project_id

  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.gke_observability.dataset_id}"

  filter = "resource.type=k8s_container"

  unique_writer_identity = true
}