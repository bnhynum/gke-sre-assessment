resource "google_container_cluster" "primary" {
  name     = "gke-primary"
  location = var.primary_region

  network    = google_compute_network.sre_vpc.id
  subnetwork = google_compute_subnetwork.primary.id

  release_channel {
    channel = "REGULAR"
  }

  node_locations = [
    "us-central1-a"
  ]

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-primary-pods"
    services_secondary_range_name = "gke-primary-services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS"
    ]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS"
    ]
  }

  node_pool {
    name               = "default-pool"
    initial_node_count = 2

    autoscaling {
      min_node_count = 1
      max_node_count = 3
    }

    node_config {
      machine_type = "e2-standard-2"
    }
  }
}

resource "google_container_cluster" "secondary" {
  name     = "gke-secondary"
  location = var.secondary_region

  network    = google_compute_network.sre_vpc.id
  subnetwork = google_compute_subnetwork.secondary.id

  release_channel {
    channel = "REGULAR"
  }

  node_locations = [
    "us-east1-b"
  ]

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-secondary-pods"
    services_secondary_range_name = "gke-secondary-services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS"
    ]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS"
    ]
  }

  node_pool {
    name               = "default-pool"
    initial_node_count = 2

    autoscaling {
      min_node_count = 1
      max_node_count = 3
    }

    node_config {
      machine_type = "e2-standard-2"
    }
  }
}