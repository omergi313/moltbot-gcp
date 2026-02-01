# Enable required APIs
resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  project = var.project_id
  service = "iam.googleapis.com"

  disable_on_destroy = false
}

# VPC Network
resource "google_compute_network" "openclaw" {
  name                    = "openclaw-network"
  project                 = var.project_id
  auto_create_subnetworks = true

  depends_on = [google_project_service.compute]
}

# Firewall: Allow SSH
resource "google_compute_firewall" "ssh" {
  name    = "openclaw-allow-ssh"
  project = var.project_id
  network = google_compute_network.openclaw.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["openclaw-vm"]
}

# Firewall: Allow Gateway port
resource "google_compute_firewall" "gateway" {
  name    = "openclaw-allow-gateway"
  project = var.project_id
  network = google_compute_network.openclaw.name

  allow {
    protocol = "tcp"
    ports    = ["18789"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["openclaw-vm"]
}

# Service Account with minimal permissions
resource "google_service_account" "openclaw" {
  project      = var.project_id
  account_id   = "openclaw-vm-sa"
  display_name = "OpenClaw VM Service Account"

  depends_on = [google_project_service.iam]
}

# Grant logging permissions to service account
resource "google_project_iam_member" "logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.openclaw.email}"
}

resource "google_project_iam_member" "monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.openclaw.email}"
}

# Static external IP
resource "google_compute_address" "openclaw" {
  name    = "openclaw-ip"
  project = var.project_id
  region  = var.region

  depends_on = [google_project_service.compute]
}

# Compute Engine VM
resource "google_compute_instance" "openclaw" {
  name         = "openclaw-vm"
  project      = var.project_id
  machine_type = "e2-medium"
  zone         = var.zone

  tags = ["openclaw-vm"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = google_compute_network.openclaw.name

    access_config {
      nat_ip = google_compute_address.openclaw.address
    }
  }

  service_account {
    email  = google_service_account.openclaw.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    startup-script = templatefile("${path.module}/../scripts/startup.sh", {
      anthropic_api_key  = var.anthropic_api_key
      gateway_token      = var.gateway_token
      telegram_bot_token = var.telegram_bot_token
    })
  }

  depends_on = [
    google_project_service.compute,
    google_compute_firewall.ssh,
    google_compute_firewall.gateway
  ]
}
