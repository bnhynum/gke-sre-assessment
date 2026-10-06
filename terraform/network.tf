resource "google_compute_network" "sre_vpc" {
  name                    = "sre-assessment-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "primary" {
  name          = "gke-primary-subnet"
  ip_cidr_range = "10.10.0.0/20"
  region        = var.primary_region
  network       = google_compute_network.sre_vpc.id

  secondary_ip_range {
    range_name    = "gke-primary-pods"
    ip_cidr_range = "10.20.0.0/16"
  }

  secondary_ip_range {
    range_name    = "gke-primary-services"
    ip_cidr_range = "10.30.0.0/20"
  }
}

resource "google_compute_subnetwork" "secondary" {
  name          = "gke-secondary-subnet"
  ip_cidr_range = "10.40.0.0/20"
  region        = var.secondary_region
  network       = google_compute_network.sre_vpc.id

  secondary_ip_range {
    range_name    = "gke-secondary-pods"
    ip_cidr_range = "10.50.0.0/16"
  }

  secondary_ip_range {
    range_name    = "gke-secondary-services"
    ip_cidr_range = "10.60.0.0/20"
  }
}