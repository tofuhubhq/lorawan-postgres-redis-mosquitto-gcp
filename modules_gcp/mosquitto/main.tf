variable "gcp_project" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_zone" {
  description = "GCP compute zone"
  type        = string
}

variable "mosquitto_instance_name" {
  description = "Name of the mosquitto instance"
  type        = string
}

variable "machine_type" {
  description = "Compute machine type"
  type        = string
}

variable "mosquitto_username" {
  type        = string
}

variable "mosquitto_password" {
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
}

variable "network_self_link" {
  type = string
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
  credentials = file("/Users/tommaso/Downloads/tofuhub-95de5791f8fb.json")
}

resource "google_compute_instance" "mosquitto" {
  name         = var.mosquitto_instance_name
  machine_type = var.machine_type
  zone         = var.gcp_zone
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = var.network_self_link
    access_config {}
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update -y
    apt-get install -y mosquitto
    mosquitto_passwd -b -c /etc/mosquitto/passwd "${var.mosquitto_username}" "${var.mosquitto_password}"
    echo "allow_anonymous false" > /etc/mosquitto/conf.d/auth.conf
    echo "password_file /etc/mosquitto/passwd" >> /etc/mosquitto/conf.d/auth.conf
    systemctl restart mosquitto
    systemctl enable mosquitto
  EOT

  tags = ["mosquitto"]
}

resource "google_compute_firewall" "allow_mosquitto" {
  name    = "allow-mosquitto"
  network = var.network_self_link  # or use `google_compute_network.vpc.name`

  allow {
    protocol = "tcp"
    ports    = ["1883"]
  }

  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]  # 👈 Optional: restrict to known clients for better security
  target_tags   = ["mosquitto"] # 👈 matches the tag on your VM
}

output "mosquitto_host" {
  value = google_compute_instance.mosquitto.network_interface[0].access_config[0].nat_ip
}

output "mosquitto_port" {
  value = 1883
}
