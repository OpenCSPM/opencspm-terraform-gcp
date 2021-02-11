## DNS

# Restricted API access zone
# https://cloud.google.com/vpc-service-controls/docs/set-up-private-connectivity
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

# CNAME redirecting *.googleapis.com to restricted.googleapis.com
resource "google_dns_record_set" "private-api-cname-records" {
  project      = google_project.collection-project.project_id
  name         = "*.${google_dns_managed_zone.private-api-zone.dns_name}"
  managed_zone = google_dns_managed_zone.private-api-zone.name
  type         = "CNAME"
  ttl          = 300
  rrdatas = ["restricted.googleapis.com."]
}

# A record for the 4 IPs under restricted.googleapis.com
resource "google_dns_record_set" "private-api-a-records" {
  project      = google_project.collection-project.project_id
  name         = "restricted.${google_dns_managed_zone.private-api-zone.dns_name}"
  managed_zone = google_dns_managed_zone.private-api-zone.name
  type         = "A"
  ttl          = 300

  rrdatas = ["199.36.153.4", "199.36.153.5", "199.36.153.6", "199.36.153.7"]
}

# Private DNS access to GCR
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

# CNAME redirecting *.gcr.io to gcr.io
resource "google_dns_record_set" "private-gcr-cname-records" {
  project      = google_project.collection-project.project_id
  name         = "*.${google_dns_managed_zone.private-gcr-zone.dns_name}"
  managed_zone = google_dns_managed_zone.private-gcr-zone.name
  type         = "CNAME"
  ttl          = 300
  rrdatas = ["gcr.io."]
}

# A record for the 4 IPs under gcr.io
resource "google_dns_record_set" "private-gcr-a-records" {
  project      = google_project.collection-project.project_id
  name         = google_dns_managed_zone.private-gcr-zone.dns_name
  managed_zone = google_dns_managed_zone.private-gcr-zone.name
  type         = "A"
  ttl          = 300

  rrdatas = ["199.36.153.4", "199.36.153.5", "199.36.153.6", "199.36.153.7"]
}
