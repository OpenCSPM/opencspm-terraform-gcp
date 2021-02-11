## Setup

# Project name entropy
resource "random_id" "random_project_id_suffix" {
  byte_length = 2
}

# Establish local vars
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

## Core Collection Project

# OpenCSPM core VM and collection project
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

# Collection Project Data Access Audit Loggign
resource "google_project_iam_audit_config" "collection-project" {
  project = google_project.collection-project.id
  service = "allServices"
  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
  audit_log_config {
    log_type = "DATA_READ"
  }
}

# Enable services in the collection project
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
