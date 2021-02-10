// Create the OpenCSPM Google SA in the GKE project
resource "google_service_account" "opencspm-exporter-sa" {
  project      = var.cluster_project_id
  account_id   = "opencspm-gke-exporter"
  display_name = var.opencspm_exporter_sa_display_name
  description  = var.opencspm_exporter_sa_description
}

// Make an IAM policy that allows the K8S SA to use workload identity to become the GCP SA
data "google_iam_policy" "opencspm-exporter-workload-identity" {
  binding {
    role = "roles/iam.workloadIdentityUser"

    members = [
      format("serviceAccount:%s.svc.id.goog[%s/%s]", var.cluster_project_id, var.k8s_namespace, var.k8s_sa_name)
    ]
  }
}

// Bind the workload identity IAM policy to the GSA
resource "google_service_account_iam_policy" "opencspm-exporter" {
  service_account_id = google_service_account.opencspm-exporter-sa.name
  policy_data        = data.google_iam_policy.opencspm-exporter-workload-identity.policy_data
}

// Attach OpenCSPM collection bucket access permissions to the Google SA.
resource "google_storage_bucket_iam_member" "opencspm-exporter-member" {
  bucket = var.collection_bucket_name
  role   = var.collection_bucket_iam_role
  member = format("serviceAccount:%s", google_service_account.opencspm-exporter-sa.email)
}
