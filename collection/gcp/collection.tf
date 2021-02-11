## Setup

# An empty GAE app is required for Cloud Run
resource "google_app_engine_application" "placeholder-app" {
  project     = google_project.collection-project.project_id
  location_id = var.cloud_run_location
}

## IAM

# Service Account for grabbing a CAI and storing it in the GCS collection Bucket
resource "google_service_account" "collection-sa" {
  project      = google_project.collection-project.project_id
  account_id   = "opencspm-collection-sa"
  display_name = "OpenCSPM Collection Service Account"
}

# Permits getting GCS collection buckets
resource "google_storage_bucket_iam_member" "collection-project-iam-get" {
  bucket = module.collection-bucket.name
  role   = "roles/storage.legacyBucketWriter"
  member = "serviceAccount:${google_service_account.collection-sa.email}"
}

# Grants the Collection Service SA access to use KMS to write to the encrypted bucket
resource "google_project_iam_member" "collection-sa-encrypt-decrypt" {
  project = google_project.collection-project.project_id

  role   = "roles/cloudkms.cryptoKeyEncrypter"
  member = "serviceAccount:${google_service_account.collection-sa.email}"

  depends_on = [google_project_service.enabled-apis]
}

# Permits collection of CAI resources at the org level
resource "google_organization_iam_member" "collection-organization-iam" {
  org_id = var.organization_id
  role   = "roles/cloudasset.viewer"
  member = "serviceAccount:${google_service_account.collection-sa.email}"
}

# Service Account for invoking CAI Collection
resource "google_service_account" "invoker-sa" {
  project      = google_project.collection-project.project_id
  account_id   = "opencspm-cai-invoker-sa"
  display_name = "OpenCSPM CAI Invoker Service Account"
}

# Grants the Google Managed CAI Service SA access to write to the collection bucket
resource "google_storage_bucket_iam_member" "collection-project-cai-bucket-writer" {
  bucket = module.collection-bucket.name
  role   = "roles/storage.legacyBucketWriter"
  member = "serviceAccount:service-${google_project.collection-project.number}@gcp-sa-cloudasset.iam.gserviceaccount.com"

  depends_on = [google_project_service.enabled-apis]
}

# Grants the Google Managed CAI Service SA access to use KMS to write to the encrypted bucket
resource "google_project_iam_member" "managed-cai-sa-encrypt-decrypt" {
  project = google_project.collection-project.project_id

  role   = "roles/cloudkms.cryptoKeyEncrypter"
  member = "serviceAccount:service-${google_project.collection-project.number}@gcp-sa-cloudasset.iam.gserviceaccount.com"

  depends_on = [google_project_service.enabled-apis]
}

## GCP CAI Collection

# Cloud Scheduler Job for invoking GCP CAI cloud run
resource "google_cloud_scheduler_job" "cai-export-trigger" {
  project          = google_project.collection-project.project_id
  name             = "cai-export-trigger"
  description      = "GCP CAI Export Trigger"
  schedule         = var.cai_collection_crontab
  time_zone        = "GMT"
  attempt_deadline = "320s"
  region           = var.region

  http_target {
    http_method = "GET"
    uri         = "${google_cloud_run_service.cai-export.status[0].url}/exportcai"

    oidc_token {
      service_account_email = google_service_account.invoker-sa.email
    }
  }

  depends_on = [google_project_service.enabled-apis, google_app_engine_application.placeholder-app]
}

# Cloud Run service to run GCP CAI Cloud Run Export
resource "google_cloud_run_service" "cai-export" {
  project  = google_project.collection-project.project_id
  name     = "opencspm-cai-exporter"
  location = var.region

  template {
    spec {
      service_account_name  = google_service_account.collection-sa.email
      container_concurrency = 1
      timeout_seconds       = 900
      containers {
        image = var.cai_exporter_image
        resources {
          limits = {
            "cpu"    = var.cai_cloud_run_cpu_limit
            "memory" = var.cai_cloud_run_mem_limit
          }
        }
        env {
          name  = "CAI_PARENT_PATH"
          value = "organizations/${var.organization_id}"
        }
        env {
          name  = "GCS_BUCKET_NAME"
          value = module.collection-bucket.name
        }
        env {
          name  = "GCS_BUCKET_FOLDER"
          value = "cai"
        }
      }
    }
  }

  depends_on = [google_project_service.enabled-apis]
}

# IAM Policy for the scheduler to invoke the cai-export cloud run service
data "google_iam_policy" "invoker" {
  binding {
    role = "roles/run.invoker"
    members = [
      "serviceAccount:${google_service_account.invoker-sa.email}",
    ]
  }
}

# Bind the IAM policy to the cloud run service allowing invocation
resource "google_cloud_run_service_iam_policy" "invoker" {
  project  = google_project.collection-project.project_id
  location = google_cloud_run_service.cai-export.location
  service  = google_cloud_run_service.cai-export.name

  policy_data = data.google_iam_policy.invoker.policy_data
}


## GCP IAM Collection

# Cloud Scheduler Job for invoking GCP IAM capture cloud run
resource "google_cloud_scheduler_job" "iam-export-trigger" {
  project          = google_project.collection-project.project_id
  name             = "iam-export-trigger"
  description      = "GCP IAM Collection Trigger"
  schedule         = var.iam_collection_crontab
  time_zone        = "GMT"
  attempt_deadline = "320s"
  region           = var.region

  http_target {
    http_method = "GET"
    uri         = "${google_cloud_run_service.iam-export.status[0].url}/exportcai"

    oidc_token {
      service_account_email = google_service_account.invoker-sa.email
    }
  }

  depends_on = [google_project_service.enabled-apis, google_app_engine_application.placeholder-app]
}

# Cloud Run service to run GCP IAM Capture
resource "google_cloud_run_service" "iam-export" {
  project  = google_project.collection-project.project_id
  name     = "opencspm-iam-exporter"
  location = var.region

  template {
    spec {
      service_account_name  = google_service_account.collection-sa.email
      container_concurrency = 1
      timeout_seconds       = 900
      containers {
        image = var.iam_exporter_image
        resources {
          limits = {
            "cpu"    = var.iam_cloud_run_cpu_limit
            "memory" = var.iam_cloud_run_mem_limit
          }
        }
        env {
          name  = "GCS_BUCKET_NAME"
          value = module.collection-bucket.name
        }
        env {
          name  = "GCS_BUCKET_FOLDER"
          value = "iam"
        }
      }
    }
  }

  depends_on = [google_project_service.enabled-apis]
}

# IAM Policy for the scheduler to invoke the cai-export cloud run service
data "google_iam_policy" "iam-invoker" {
  binding {
    role = "roles/run.invoker"
    members = [
      "serviceAccount:${google_service_account.invoker-sa.email}",
    ]
  }
}

# Bind the IAM policy to the cloud run service allowing invocation
resource "google_cloud_run_service_iam_policy" "iam-invoker" {
  project  = google_project.collection-project.project_id
  location = google_cloud_run_service.iam-export.location
  service  = google_cloud_run_service.iam-export.name

  policy_data = data.google_iam_policy.iam-invoker.policy_data
}
