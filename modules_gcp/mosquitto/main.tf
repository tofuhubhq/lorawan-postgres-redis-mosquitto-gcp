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

variable "network_self_link" {
  type = string
}

provider "google" {
  project = var.gcp_project
  zone    = var.gcp_zone
}

resource "google_compute_instance" "mosquitto" {
  name         = var.mosquitto_instance_name
  machine_type = var.machine_type

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

output "mosquitto_host" {
  value = google_compute_instance.mosquitto.network_interface[0].access_config[0].nat_ip
}

output "mosquitto_port" {
  value = 1883
}
