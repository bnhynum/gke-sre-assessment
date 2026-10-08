# IAM design for the GKE SRE assessment
#
# These bindings are intentionally conditional. The assessment environment does
# not provide real organization-managed Developer, Operations, or SRE groups,
# so no placeholder principals receive access merely to satisfy the design.

variable "developer_group" {
  description = "Organization-managed Developer Google Group email. Leave null when unavailable."
  type        = string
  default     = null
}

variable "operations_group" {
  description = "Organization-managed Operations Google Group email. Leave null when unavailable."
  type        = string
  default     = null
}

variable "sre_group" {
  description = "Organization-managed SRE Google Group email. Leave null when unavailable."
  type        = string
  default     = null
}

variable "cicd_service_account" {
  description = "CI/CD service account email. Prefer federated access rather than service-account keys. Leave null when unavailable."
  type        = string
  default     = null
}

# Developers
resource "google_project_iam_member" "developer_logging_viewer" {
  count = var.developer_group == null ? 0 : 1

  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "group:${var.developer_group}"
}

resource "google_project_iam_member" "developer_monitoring_viewer" {
  count = var.developer_group == null ? 0 : 1

  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "group:${var.developer_group}"
}

# Operations
resource "google_project_iam_member" "operations_container_viewer" {
  count = var.operations_group == null ? 0 : 1

  project = var.project_id
  role    = "roles/container.viewer"
  member  = "group:${var.operations_group}"
}

resource "google_project_iam_member" "operations_compute_viewer" {
  count = var.operations_group == null ? 0 : 1

  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "group:${var.operations_group}"
}

resource "google_project_iam_member" "operations_logging_viewer" {
  count = var.operations_group == null ? 0 : 1

  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "group:${var.operations_group}"
}

resource "google_project_iam_member" "operations_monitoring_viewer" {
  count = var.operations_group == null ? 0 : 1

  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "group:${var.operations_group}"
}

# SRE
resource "google_project_iam_member" "sre_container_developer" {
  count = var.sre_group == null ? 0 : 1

  project = var.project_id
  role    = "roles/container.developer"
  member  = "group:${var.sre_group}"
}

resource "google_project_iam_member" "sre_logging_viewer" {
  count = var.sre_group == null ? 0 : 1

  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "group:${var.sre_group}"
}

resource "google_project_iam_member" "sre_monitoring_viewer" {
  count = var.sre_group == null ? 0 : 1

  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "group:${var.sre_group}"
}

resource "google_project_iam_member" "sre_bigquery_job_user" {
  count = var.sre_group == null ? 0 : 1

  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "group:${var.sre_group}"
}

# CI/CD
resource "google_project_iam_member" "cicd_container_developer" {
  count = var.cicd_service_account == null ? 0 : 1

  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${var.cicd_service_account}"
}
