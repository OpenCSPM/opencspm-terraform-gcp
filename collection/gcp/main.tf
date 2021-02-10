resource "random_id" "random_project_id_suffix" {
  byte_length = 2
}

locals {
  base_project_id   = var.project_id == "" ? var.project_name : var.project_id
  project_org_id    = var.folder_id != "" ? null : var.organization_id
  project_folder_id = var.folder_id != "" ? var.folder_id : null
  temp_project_id = var.random_project_id ? format(
    "%s-%s",
    local.base_project_id,
    random_id.random_project_id_suffix.hex,
  ) : local.base_project_id
  enabled_services = var.enabled_services
  cloud_init       = "${path.module}/assets/cloud-config.yaml"
}

# OpenCSPM project
resource "google_project" "collection-project" {
  name       = var.project_name
  project_id = local.temp_project_id
  org_id     = local.project_org_id
  folder_id  = local.project_folder_id

  billing_account = var.billing_account
  labels          = var.project_labels

  auto_create_network = false
  skip_delete         = true
}

resource "google_project_service" "enabled-apis" {
  project            = google_project.collection-project.project_id
  for_each           = toset(local.enabled_services)
  service            = each.value
  disable_on_destroy = false
  provisioner "local-exec" {
    command = "sleep 60"
  }
  depends_on = [google_project.collection-project]
}

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

# Permits collection of CAI resources at the org level
resource "google_organization_iam_member" "collection-organization-iam" {
  org_id = var.organization_id
  role   = "roles/cloudasset.viewer"
  member = "serviceAccount:${google_service_account.collection-sa.email}"
}
resource "google_storage_bucket_iam_member" "collection-project-cai-bucket-writer" {
  bucket = module.collection-bucket.name
  role   = "roles/storage.legacyBucketWriter"
  member = "serviceAccount:service-${google_project.collection-project.number}@gcp-sa-cloudasset.iam.gserviceaccount.com"

  depends_on = [google_project_service.enabled-apis]
}

# Permits Darkbit Administrators
resource "google_project_iam_member" "darkbit-administrators" {
  count   = var.enable_darkbit_administrators ? 1 : 0
  project = google_project.collection-project.project_id
  role    = "roles/owner"
  member  = "group:${var.darkbit_administrator_group}"
}

# The collection bucket
module "collection-bucket" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "~> 1.7"

  project_id = google_project.collection-project.project_id
  prefix     = var.collection_bucket_prefix
  location   = var.collection_bucket_location
  names      = ["opencspm"]

  bucket_policy_only = {
    opencspm = true
  }
  versioning = {
    opencspm = true
  }

  depends_on = [google_project_service.enabled-apis]
}

# Service Account for loading data from the GCS collection Bucket
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
resource "google_storage_bucket_iam_member" "loader-iam-viewer" {
  bucket = module.collection-bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.loader-sa.email}"
}

# The backup bucket
module "backup-bucket" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "~> 1.7"

  project_id = google_project.collection-project.project_id
  prefix     = var.backup_bucket_prefix
  location   = var.backup_bucket_location
  names      = ["opencspm"]

  bucket_policy_only = {
    opencspm = true
  }
  versioning = {
    opencspm = true
  }

  depends_on = [google_project_service.enabled-apis]
}
resource "google_storage_bucket_iam_member" "loader-iam-backups" {
  bucket = module.backup-bucket.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.loader-sa.email}"
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

# Service Account for invoking CAI Collection
resource "google_service_account" "invoker-sa" {
  project      = google_project.collection-project.project_id
  account_id   = "opencspm-cai-invoker-sa"
  display_name = "OpenCSPM CAI Invoker Service Account"
}

# Required for Cloud Run
resource "google_app_engine_application" "placeholder-app" {
  project     = google_project.collection-project.project_id
  location_id = var.cloud_run_location
}

# Cloud Scheduler Job for invoking CAI cloud run
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

# Cloud Run service to run CAI Export
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

# Cloud Scheduler Job for invoking IAM cloud run
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

# Cloud Run service to run CAI Export
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

# Create a new, custom VPC for the OpenCSPM instance
resource "google_compute_network" "opencspm-network" {
  project     = google_project.collection-project.project_id
  name        = "opencspm-vpc"
  description = "OpenCSPM VPC"

  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Create a single regional subnet
resource "google_compute_subnetwork" "opencspm-subnet" {
  project = google_project.collection-project.project_id
  name    = "opencspm-subnet"

  region        = var.region
  network       = google_compute_network.opencspm-network.id
  ip_cidr_range = var.subnet_cidr

  private_ip_google_access = true
}

# Allow SSH from IAP to GCE Instance
resource "google_compute_firewall" "iap-access" {
  project = google_project.collection-project.project_id
  name    = "opencspm-iap-access"
  network = google_compute_network.opencspm-network.id

  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = var.vm_network_ports
  }
  source_ranges = ["35.235.240.0/20"]
  target_tags   = var.vm_instance_tags

  priority = 1000
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Deny Egress explicitly
resource "google_compute_firewall" "deny-egress" {
  project = google_project.collection-project.project_id
  name    = "opencspm-deny-egress"
  network = google_compute_network.opencspm-network.id

  direction = "EGRESS"
  deny {
    protocol = "all"
  }
  destination_ranges = ["0.0.0.0/0"]

  priority = 65535
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Allow GCP API Egress explicitly
resource "google_compute_firewall" "gcp-api-access" {
  project = google_project.collection-project.project_id
  name    = "opencspm-gcp-api-access"
  network = google_compute_network.opencspm-network.id

  direction = "EGRESS"
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  destination_ranges = ["199.36.153.4/30"]
  target_tags        = var.vm_instance_tags

  priority = 1000
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

### Allow Egress via NAT
#resource "google_compute_router" "opencspm-router" {
#  project = google_project.collection-project.project_id
#  name    = "opencspm-router"
#  region  = google_compute_subnetwork.opencspm-subnet.region
#  network = google_compute_network.opencspm-network.id
#
#  bgp {
#    asn = 64514
#  }
#}
#resource "google_compute_router_nat" "opencspm-nat" {
#  project = google_project.collection-project.project_id
#  name                               = "opencspm-nat"
#  router                             = google_compute_router.opencspm-router.name
#  region                             = google_compute_router.opencspm-router.region
#  nat_ip_allocate_option             = "AUTO_ONLY"
#  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
#
#  log_config {
#    enable = true
#    filter = "ERRORS_ONLY"
#  }
#}

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

## DNS for private API access
resource "google_dns_managed_zone" "private-api-zone" {
  project      = google_project.collection-project.project_id
  name        = "private-google-api-access"
  dns_name    = "googleapis.com."
  description = "private Google API Access Zone"
  labels = {
    private = "true"
  }

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.opencspm-network.id
    }
  }
}
resource "google_dns_record_set" "private-api-cname-records" {
  project      = google_project.collection-project.project_id
  name         = "*.${google_dns_managed_zone.private-api-zone.dns_name}"
  managed_zone = google_dns_managed_zone.private-api-zone.name
  type         = "CNAME"
  ttl          = 300
  rrdatas = ["restricted.googleapis.com."]
}
resource "google_dns_record_set" "private-api-a-records" {
  project      = google_project.collection-project.project_id
  name         = "restricted.${google_dns_managed_zone.private-api-zone.dns_name}"
  managed_zone = google_dns_managed_zone.private-api-zone.name
  type         = "A"
  ttl          = 300

  rrdatas = ["199.36.153.4", "199.36.153.5", "199.36.153.6", "199.36.153.7"]
}

resource "google_dns_managed_zone" "private-gcr-zone" {
  project      = google_project.collection-project.project_id
  name        = "private-google-gcr-access"
  dns_name    = "gcr.io."
  description = "Private GCR Access Zone"
  labels = {
    private = "true"
  }

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.opencspm-network.id
    }
  }
}
resource "google_dns_record_set" "private-gcr-cname-records" {
  project      = google_project.collection-project.project_id
  name         = "*.${google_dns_managed_zone.private-gcr-zone.dns_name}"
  managed_zone = google_dns_managed_zone.private-gcr-zone.name
  type         = "CNAME"
  ttl          = 300
  rrdatas = ["gcr.io."]
}
resource "google_dns_record_set" "private-gcr-a-records" {
  project      = google_project.collection-project.project_id
  name         = google_dns_managed_zone.private-gcr-zone.dns_name
  managed_zone = google_dns_managed_zone.private-gcr-zone.name
  type         = "A"
  ttl          = 300

  rrdatas = ["199.36.153.4", "199.36.153.5", "199.36.153.6", "199.36.153.7"]
}
