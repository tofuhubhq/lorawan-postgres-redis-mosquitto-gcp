variable "gcp_project" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_zone" {
  description = "GCP compute zone"
  type        = string
}

variable "redis_instance_name" {
  description = "Name of the redis instance"
  type        = string
}

variable "machine_type" {
  description = "Compute machine type"
  type        = string
}

variable "redis_password" {
  description = "Password for redis"
  type        = string
}

variable "network_self_link" {
  description = "VPC self link"
  type        = string
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_zone
  credentials = file("/Users/tommaso/Downloads/tofuhub-95de5791f8fb.json")
}

resource "google_compute_instance" "redis" {
  name         = var.redis_instance_name
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
    apt-get install -y redis-server
    sed -i "s/^#\\?requirepass .*/requirepass ${var.redis_password}/" /etc/redis/redis.conf
    sed -i "s/^bind .*/bind 0.0.0.0/" /etc/redis/redis.conf
    sed -i "s/^protected-mode .*/protected-mode no/" /etc/redis/redis.conf
    systemctl enable redis-server
    systemctl restart redis-server
  EOT

  tags = ["redis"]
}

resource "google_compute_firewall" "allow_redis" {
  name    = "allow-redis"
  network = var.network_self_link

  allow {
    protocol = "tcp"
    ports    = ["6379"]
  }

  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]  # ⚠️ or restrict to a known range
  target_tags   = ["redis"]     # 👈 this matches the VM's `tags = ["redis"]`
}

output "redis_host" {
  value = google_compute_instance.redis.network_interface[0].access_config[0].nat_ip
}

output "redis_password" {
  value     = var.redis_password
  sensitive = true
}
