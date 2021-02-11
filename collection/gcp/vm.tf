## IAM

# Service Account for accessing/loading data from the GCS collection Bucket
resource "google_service_account" "loader-sa" {
  project      = google_project.collection-project.project_id
  account_id   = "opencspm-loader-sa"
  display_name = "OpenCSPM Loader Service Account"
}

# IAM allowing the Loader Service Account to pull from the GCS collection Bucket
resource "google_storage_bucket_iam_member" "loader-iam-reader" {
  bucket = module.collection-bucket.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.loader-sa.email}"
}

# IAM allowing the Loader Service Account to pull from the GCS collection Bucket
resource "google_storage_bucket_iam_member" "loader-iam-viewer" {
  bucket = module.collection-bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.loader-sa.email}"
}

# IAM allowing the GCS Managed Service Account to Encrypt/Decrypt backups via KMS
resource "google_project_iam_member" "grant-google-storage-service-encrypt-decrypt" {
  project = google_project.collection-project.project_id

  role   = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member = "serviceAccount:service-${google_project.collection-project.number}@gs-project-accounts.iam.gserviceaccount.com"

  depends_on = [google_project_service.enabled-apis]
}

# Allows loader SA (attached to the VM) to read/manage files to load
resource "google_storage_bucket_iam_member" "loader-iam-backups" {
  bucket = module.backup-bucket.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.loader-sa.email}"
}

# Allows loader SA (attached to the VM) to also make encrypted backups
resource "google_project_iam_member" "loader-iam-backups-encrypt-decrypt" {
  project = google_project.collection-project.project_id

  role   = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member = "serviceAccount:${google_service_account.loader-sa.email}"

  depends_on = [google_project_service.enabled-apis]
}

# IAM allowing the Loader Service Account to send GCP logs
resource "google_project_iam_member" "loader-iam-logging" {
  project = google_project.collection-project.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.loader-sa.email}"
}

# IAM allowing the Loader Service Account to send GCP metrics
resource "google_project_iam_member" "loader-iam-monitoring" {
  project = google_project.collection-project.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.loader-sa.email}"
}

## Compute

# OpenCSPM GCE Instance
resource "google_compute_instance" "opencspm-core" {
  project     = google_project.collection-project.project_id
  name        = "opencspm-core"
  description = "OpenCSPM Core Instance"

  tags           = var.vm_instance_tags
  labels         = var.project_labels
  machine_type   = var.vm_instance_type
  zone           = var.vm_instance_zone
  can_ip_forward = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  boot_disk {
    initialize_params {
      type  = var.vm_instance_disk_type
      image = var.vm_instance_disk_image
      size  = var.vm_instance_disk_size
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.opencspm-subnet.id
  }

  service_account {
    email  = google_service_account.loader-sa.email
    scopes = var.vm_instance_scopes
  }

  metadata = {
    google-logging-enabled    = true
    google-monitoring-enabled = true
    user-data                 = data.template_file.cloud-config.*.rendered[0]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  allow_stopping_for_update = true

  # Give breathing room on destroy/create
  provisioner "local-exec" {
    command = "sleep 20"
  }
}

data "template_file" "cloud-config" {
  template = file(local.cloud_init)

  vars = {
    custom_var = "test"
  }
}
