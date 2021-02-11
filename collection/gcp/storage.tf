## Collection KMS and Bucket

# The collection bucket with default KMS encryption
resource "random_id" "collection_kms_random" {
  prefix      = var.collection_kms_key_ring_prefix
  byte_length = "8"
}

# The KMS Keyring
resource "google_kms_key_ring" "opencspm-collection" {
  name     = random_id.collection_kms_random.hex
  location = var.kms_multi_region_name
  project  = google_project.collection-project.project_id

  depends_on = [google_project_service.enabled-apis]
}

# The KMS Key
resource "google_kms_crypto_key" "opencspm-collection-key" {
  name            = var.collection_kms_key_name
  key_ring        = google_kms_key_ring.opencspm-collection.id
  rotation_period = var.collection_kms_key_rotation
}

# The collection bucket
module "collection-bucket" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "~> 1.7"

  project_id = google_project.collection-project.project_id
  prefix     = var.collection_bucket_prefix
  location   = var.collection_bucket_location
  names      = ["opencspm"]

  encryption_key_names = {
    opencspm = google_kms_crypto_key.opencspm-collection-key.self_link
  }

  bucket_policy_only = {
    opencspm = true
  }
  versioning = {
    opencspm = true
  }

  # Delete after N (720) days, delete old versions > 180 (manifest.txt), move to cheaper storage class after N (60) days
  lifecycle_rules = [
  {
    action = {
      type = "Delete"
    }
    condition = {
      age        = var.collection_bucket_lifecycle_delete_all_data_after_num_days
      with_state = "ANY"
    }
  },
  {
    action = {
      type = "Delete"
    }
    condition = {
      num_newer_versions = 180
    }
  },
  {
    action = {
      type = "SetStorageClass"
      storage_class = var.collection_bucket_lifecycle_storage_class_downgrade_name
    }
    condition = {
      age                   = var.collection_bucket_lifecycle_storage_class_downgrade_age_in_days
      matches_storage_class = "MULTI_REGIONAL,STANDARD,DURABLE_REDUCED_AVAILABILITY"
    }
  }
  ]

  depends_on = [google_project_service.enabled-apis]
}

## Backup KMS and Bucket

# The backup bucket with default KMS encryption
resource "random_id" "backup_kms_random" {
  prefix      = var.backup_kms_key_ring_prefix
  byte_length = "8"
}

# The KMS Keyring
resource "google_kms_key_ring" "opencspm-backup" {
  name     = random_id.backup_kms_random.hex
  location = var.kms_multi_region_name
  project  = google_project.collection-project.project_id

  depends_on = [google_project_service.enabled-apis]
}

# The KMS Key
resource "google_kms_crypto_key" "opencspm-backup-key" {
  name            = var.backup_kms_key_name
  key_ring        = google_kms_key_ring.opencspm-backup.id
  rotation_period = var.backup_kms_key_rotation
}

module "backup-bucket" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "~> 1.7"

  project_id = google_project.collection-project.project_id
  prefix     = var.backup_bucket_prefix
  location   = var.backup_bucket_location
  names      = ["opencspm"]

  encryption_key_names = {
    opencspm = google_kms_crypto_key.opencspm-backup-key.self_link
  }

  bucket_policy_only = {
    opencspm = true
  }

  # Delete after N (365) days, move to cheaper storage class after N (10) days
  lifecycle_rules = [
  {
    action = {
      type = "Delete"
    }
    condition = {
      age        = var.backup_bucket_lifecycle_delete_all_data_after_num_days
      with_state = "ANY"
    }
  },
  {
    action = {
      type = "SetStorageClass"
      storage_class = var.backup_bucket_lifecycle_storage_class_downgrade_name
    }
    condition = {
      age                   = var.backup_bucket_lifecycle_storage_class_downgrade_age_in_days
      matches_storage_class = "MULTI_REGIONAL,STANDARD,DURABLE_REDUCED_AVAILABILITY"
    }
  }
  ]

  depends_on = [google_project_service.enabled-apis]
}
