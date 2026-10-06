variable "project_id" {
  description = "GCP project ID for the SRE assessment"
  type        = string
  default     = "project-19ae3503-8d3c-48b5-9d8"
}

variable "primary_region" {
  description = "Primary GKE region"
  type        = string
  default     = "us-central1"
}

variable "secondary_region" {
  description = "Secondary GKE region"
  type        = string
  default     = "us-east1"
}