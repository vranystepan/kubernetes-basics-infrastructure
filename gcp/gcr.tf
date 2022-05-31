resource "google_container_registry" "registry" {
  project  = var.project_id
  location = "EU"

  depends_on = [
    google_project_service.containerregistry,
    google_project_service.artifactregistry,
  ]
}
