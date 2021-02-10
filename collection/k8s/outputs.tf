// GCP SA ID
output "opencspm_exporter_sa_id" {
  description = "The id of the GCP service account used for OpenCSPM exporting"
  value       = google_service_account.opencspm-exporter-sa.id
}

// GCP SA Email
output "opencspm_exporter_sa_email" {
  description = "The email of the GCP service account used for OpenCSPM exporting"
  value       = google_service_account.opencspm-exporter-sa.email
}
