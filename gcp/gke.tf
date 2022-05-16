resource "google_container_cluster" "main" {
  name                     = "workshops-01"
  location                 = "${var.region}-a"
  initial_node_count       = 1
  enable_shielded_nodes    = false
  remove_default_node_pool = true

  depends_on = [
    google_project_service.iam,
    google_project_service.container,
    google_project_service.cloudresourcemanager,
    google_project_service.servicenetworking,
    google_project_service.compute,
  ]
}

resource "google_container_node_pool" "default" {
  name       = "default"
  cluster    = google_container_cluster.main.name
  node_count = 4
  location   = google_container_cluster.main.location

  node_config {
    machine_type = "e2-standard-4"
  }

  autoscaling {
    max_node_count = 5
    min_node_count = 1
  }

  lifecycle {
    ignore_changes = [
      node_count,
    ]
  }
}
