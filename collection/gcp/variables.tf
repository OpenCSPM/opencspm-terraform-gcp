# Required 

variable "organization_id" {
  description = "The organization id for the associated services"
  type        = string
}

variable "folder_id" {
  description = "The ID of the folder to place the collection project under (optional)"
  type        = string
}

variable "billing_account" {
  description = "The ID of the billing account to associate this project with"
  type        = string
}

variable "collection_bucket_prefix" {
  description = "The prefix for the bucket name.  The suffix is 'opencspm'"
  type        = string
}

variable "backup_bucket_prefix" {
  description = "The prefix for the bucket name.  The suffix is 'opencspm'"
  type        = string
}

variable "cai_exporter_image" {
  description = "The image path and tag"
  type        = string
}

variable "iam_exporter_image" {
  description = "The image path and tag"
  type        = string
}


# Optional

## Network
variable "region" {
  description = "The primary region for OpenCSPM"
  type        = string
  default     = "us-central1"
}
variable "subnet_cidr" {
  description = "The CIDR for the OpenCSPM GCE Subnet"
  type        = string
  default     = "172.31.254.240/29"
}

## Project
variable "random_project_id" {
  description = "Adds a suffix of 4 random characters to the `project_id`"
  type        = bool
  default     = true
}
variable "project_name" {
  description = "The name of the project to create in the org/folder"
  type        = string
  default     = "opencspm-collection"
}
variable "project_id" {
  description = "The id of the project to create in the org/folder"
  type        = string
  default     = ""
}
variable "enabled_services" {
  description = "The services to enable in the collection project"
  type        = list
  default = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
    "run.googleapis.com",
    "cloudasset.googleapis.com",
    "cloudscheduler.googleapis.com",
    "monitoring.googleapis.com",
    "dns.googleapis.com",
    "cloudkms.googleapis.com",
  ]
}
variable "project_labels" {
  description = "The key/value pairs to add to the project"
  type        = map(string)
  default     = { "opencspm" : "collection" }
}

## Collection - Scheduler and Bucket
variable "cai_collection_crontab" {
  description = "The crontab entry for how frequent to run the CAI collection. Default is 4:14 UTC daily"
  type        = string
  default     = "14 4 * * *"
}
variable "iam_collection_crontab" {
  description = "The crontab entry for how frequent to run the CAI collection. Default is 4:10 UTC daily"
  type        = string
  default     = "10 4 * * *"
}
variable "collection_bucket_location" {
  description = "The location of the bucket.  US or EU are common choices"
  default     = "US"
  type        = string
}
variable "collection_bucket_lifecycle_storage_class_downgrade_name" {
  description = "Collection bucket lifecycle policy.  Downgraded storage class name"
  default     = "NEARLINE"
  type        = string
}
variable "collection_bucket_lifecycle_storage_class_downgrade_age_in_days" {
  description = "Collection bucket lifecycle policy.  Downgraded storage class after N days"
  default     = 60
  type        = number
}
variable "collection_bucket_lifecycle_delete_all_data_after_num_days" {
  description = "Collection bucket lifecycle policy.  Delete data after N days"
  default     = 730
  type        = number
}
variable "backup_bucket_location" {
  description = "The location of the bucket.  US or EU are common choices"
  default     = "US"
  type        = string
}
variable "backup_bucket_lifecycle_storage_class_downgrade_name" {
  description = "Backup bucket lifecycle policy.  Downgraded storage class name"
  default     = "NEARLINE"
  type        = string
}
variable "backup_bucket_lifecycle_storage_class_downgrade_age_in_days" {
  description = "Backup bucket lifecycle policy.  Downgraded storage class after N days"
  default     = 10
  type        = number
}
variable "backup_bucket_lifecycle_delete_all_data_after_num_days" {
  description = "Backup bucket lifecycle policy.  Delete data after N days"
  default     = 365
  type        = number
}

## Collection - Cloud Run General
variable "cloud_run_location" {
  description = "A geo where cloud run should live"
  type        = string
  default     = "us-central"
}

## Collection - Cloud Run CAI Exporter
variable "cai_cloud_run_cpu_limit" {
  description = "How many vCPUs. Must be 1000m, 2000m, 4000m, or 8000m"
  type        = string
  default     = "1000m"
}
variable "cai_cloud_run_mem_limit" {
  description = "How much memory. 128Mi, 256Mi"
  type        = string
  default     = "128Mi"
}
## Collection - Cloud Run IAM Collector/Exporter
variable "iam_cloud_run_cpu_limit" {
  description = "How many vCPUs. Must be 1000m, 2000m, 4000m, or 8000m"
  type        = string
  default     = "1000m"
}
variable "iam_cloud_run_mem_limit" {
  description = "How much memory. 128Mi, 256Mi"
  type        = string
  default     = "128Mi"
}

## GCE VM - OpenCSPM Instance
variable "vm_instance_zone" {
  description = "Zone to run the OpenCSPM instance in.  Must be inside region"
  type        = string
  default     = "us-central1-a"
}
variable "vm_instance_type" {
  description = "OpenCSPM VM instance type.  Recommend 2+ cpu, 8+GB memory"
  type        = string
  default     = "e2-standard-2"
}
variable "vm_instance_disk_type" {
  description = "Type of disk for the OpenCSPM VM. pd-standard or pd-ssd"
  type        = string
  default     = "pd-standard"
}
variable "vm_instance_disk_image" {
  description = "Full path to the OpenCSPM VM's disk image."
  type        = string
  default     = "projects/cos-cloud/global/images/family/cos-stable"
}
variable "vm_instance_disk_size" {
  description = "Size in GB of the OpenCSPM VM's disk"
  type        = string
  default     = "120"
}
variable "vm_instance_scopes" {
  description = ""
  type        = list
  default = [
    "https://www.googleapis.com/auth/source.read_only",
    "https://www.googleapis.com/auth/devstorage.read_write",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring.write",
  ]
}
variable "vm_network_ports" {
  description = "TCP Ports to allow via IAP to the instance"
  type        = list
  default     = ["22"]
}
variable "vm_instance_tags" {
  description = "Network tags to add to the OpenCSPM GCE Instance"
  type        = list
  default     = ["opencspm"]
}

variable "kms_multi_region_name" {
  description = "The multi-region name where KMS should be made.  Needs to align with the GCS multi-region. See: https://cloud.google.com/kms/docs/locations#multi_regional"
  type        = string
  default     = "us"
}

variable "collection_kms_key_ring_prefix" {
  description = "The prefix of the kms keyring name used to encrypt collected data in the collection GCS bucket"
  type        = string
  default     = "opencspm-collection"
}

variable "collection_kms_key_name" {
  description = "String value to use for the name of the collection KMS crypto key."
  default     = "opencspm-collection-key"
  type        = string
}

variable "collection_kms_key_rotation" {
  description = "String value to use for the name of the collection KMS crypto key."
  default     = "604800s"
  type        = string
}

variable "backup_kms_key_ring_prefix" {
  description = "The prefix of the kms keyring name used to encrypt backups in the backup GCS bucket"
  type        = string
  default     = "opencspm-backup"
}

variable "backup_kms_key_name" {
  description = "String value to use for the name of the KMS crypto key."
  default     = "opencspm-backup-key"
  type        = string
}

variable "backup_kms_key_rotation" {
  description = "String value to use for the name of the backup KMS crypto key."
  default     = "604800s"
  type        = string
}

variable "enable_darkbit_administrators" {
  description = "Boolean to enable Darkbit Administrator access to the collection project"
  type        = bool
  default     = false
}

variable "darkbit_administrator_group" {
  description = "The group to grant IAM access to manage the entire project"
  type        = string
  default     = "auditors@darkbit.io"
}
