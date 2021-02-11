# Required 

variable "cluster_project_id" {
  description = "The project id where the GKE cluster lives"
  type        = string
}

variable "collection_project_id" {
  description = "The project id where the collection bucket lives"
  type        = string
}

variable "collection_bucket_name" {
  description = "The OpenCSPM collection bucket name"
  type        = string
}

# Defaults that can be overridden

variable "collection_bucket_iam_role" {
  description = "The OpenCSPM collection bucket IAM role"
  type        = string
  default     = "roles/storage.legacyBucketWriter"
}

variable "k8s_namespace" {
  description = "The namespace where the OpenCSPM k8s-cai-exporter cronjob runs"
  type        = string
  default     = "opencspm"
}

variable "k8s_sa_name" {
  description = "The name of the Kubernetes ServiceAccount used by the OpenCSPM cronjob pod"
  type        = string
  default     = "opencspm"
}

variable "opencspm_exporter_sa_display_name" {
  description = "The display name of the SA used by OpenCSPM to write to the collection bucket"
  type        = string
  default     = "OpenCSPM GKE Exporter"
}

variable "opencspm_exporter_sa_description" {
  description = "The description of the SA used by OpenCSPM to write to the collection bucket"
  type        = string
  default     = "OpenCSPM GKE Resource Exporter using Workload Identity"
}
