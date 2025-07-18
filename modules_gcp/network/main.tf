variable "gcp_project" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
}

variable "gcp_network_name" {
  description = "Name of VPC network"
  type        = string
}

variable "gcp_firewall_name" {
  description = "Name of SSH firewall rule"
  type        = string
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

resource "google_compute_network" "vpc" {
  name                    = var.gcp_network_name
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "ssh" {
  name    = var.gcp_firewall_name
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

output "network_name" {
  value = google_compute_network.vpc.name
}

output "network_self_link" {
  value = google_compute_network.vpc.self_link
}
