## General IAM

# Permits Darkbit Administrators
resource "google_project_iam_member" "darkbit-administrators" {
  count   = var.enable_darkbit_administrators ? 1 : 0
  project = google_project.collection-project.project_id
  role    = "roles/owner"
  member  = "group:${var.darkbit_administrator_group}"
}
