variable "gcp_project" {
  type = string
}

variable "gcp_zone" {
  type = string
}

variable "instance_count" {
  type    = number
  default = 1
}

variable "machine_type" {
  type = string
}

variable "network_self_link" {
  type = string
}

variable "mosquitto_host" { type = string }
variable "mosquitto_port" { type = number }
variable "mosquitto_username" { type = string }
variable "mosquitto_password" { type = string }

variable "postgres_host" { type = string }
variable "postgres_port" { type = number }
variable "postgres_db_name" { type = string }
variable "postgres_user" { type = string }
variable "postgres_password" { type = string }

variable "redis_host" { type = string }
variable "redis_password" { type = string }

provider "google" {
  project = var.gcp_project
  zone    = var.gcp_zone
}

resource "google_compute_instance" "chirpstack" {
  count        = var.instance_count
  name         = "chirpstack-${count.index}"
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
    set -eux
    apt-get update -y
    apt-get install -y docker.io docker-compose git
    git clone https://github.com/tofuhubhq/chirpstack-docker.git /opt/chirpstack
    cat <<EOFENV >/opt/chirpstack/.env
MQTT_BROKER_HOST=${var.mosquitto_username}:${var.mosquitto_password}@${var.mosquitto_host}
POSTGRESQL_HOST=postgres://${var.postgres_user}:${var.postgres_password}@${var.postgres_host}:${var.postgres_port}/${var.postgres_db_name}?sslmode=disable
REDIS_HOST=default:${var.redis_password}@${var.redis_host}
EOFENV
    cd /opt/chirpstack
    docker-compose up --build -d
  EOT

  tags = ["chirpstack"]
}

output "chirpstack_instance_ips" {
  value = [for i in google_compute_instance.chirpstack : i.network_interface[0].access_config[0].nat_ip]
}
