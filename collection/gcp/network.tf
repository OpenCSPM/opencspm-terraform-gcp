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
