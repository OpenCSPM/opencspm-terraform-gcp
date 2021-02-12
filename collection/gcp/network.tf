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

# Allow GCP API and Github Repo Egress
resource "google_compute_firewall" "gcp-api-access" {
  project = google_project.collection-project.project_id
  name    = "opencspm-gcp-api-access"
  network = google_compute_network.opencspm-network.id

  direction = "EGRESS"
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  destination_ranges = [
    "199.36.153.4/30",
    "192.30.252.0/22",
    "185.199.108.0/22",
    "140.82.112.0/20",
    "13.114.40.48/32",
    "52.192.72.89/32",
    "52.69.186.44/32",
    "15.164.81.167/32",
    "52.78.231.108/32",
    "13.234.176.102/32",
    "13.234.210.38/32",
    "13.229.188.59/32",
    "13.250.177.223/32",
    "52.74.223.119/32",
    "13.236.229.21/32",
    "13.237.44.5/32",
    "52.64.108.95/32",
    "18.228.52.138/32",
    "18.228.67.229/32",
    "18.231.5.6/32",
    "18.181.13.223/32",
    "54.238.117.237/32",
    "54.168.17.15/32",
    "3.34.26.58/32",
    "13.125.114.27/32",
    "3.7.2.84/32",
    "3.6.106.81/32",
    "18.140.96.234/32",
    "18.141.90.153/32",
    "18.138.202.180/32",
    "52.63.152.235/32",
    "3.105.147.174/32",
    "3.106.158.203/32",
    "54.233.131.104/32",
    "18.231.104.233/32",
    "18.228.167.86/32"
  ]
  target_tags        = var.vm_instance_tags

  priority = 1000
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

## Allow Egress via NAT
resource "google_compute_router" "opencspm-router" {
  project = google_project.collection-project.project_id
  name    = "opencspm-router"
  region  = google_compute_subnetwork.opencspm-subnet.region
  network = google_compute_network.opencspm-network.id

  bgp {
    asn = 64514
  }
}
resource "google_compute_router_nat" "opencspm-nat" {
  project = google_project.collection-project.project_id
  name                               = "opencspm-nat"
  router                             = google_compute_router.opencspm-router.name
  region                             = google_compute_router.opencspm-router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
