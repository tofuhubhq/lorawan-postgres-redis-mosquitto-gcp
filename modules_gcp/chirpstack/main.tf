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

variable "ca_certificate" {
  description = "DigitalOcean CA certificate for secure DB connection"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
}

variable "private_key_path" {
  description = "Path to your private SSH key"
  type        = string
}

resource "local_file" "chirpstack_env" {
  filename = "${path.module}/tmp/chirpstack.env"
  content  = <<EOT
  MQTT_BROKER_HOST=${var.mosquitto_username}:${var.mosquitto_password}@${var.mosquitto_host}
  POSTGRESQL_HOST=postgres://${var.postgres_user}:${var.postgres_password}@${var.postgres_host}:${var.postgres_port}/${var.postgres_db_name}?sslmode=require
  REDIS_HOST=default:${var.redis_password}@${var.redis_host}
  EOT
}

resource "local_file" "ca_cert" {
  filename = "${path.module}/tmp/ca-certificate.crt"
  content  = var.ca_certificate
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
  credentials = file("/Users/tommaso/Downloads/tofuhub-95de5791f8fb.json")
}

resource "google_compute_instance" "chirpstack" {
  count        = var.instance_count
  name         = "chirpstack-${count.index}"
  machine_type = var.machine_type
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.private_key_path)
    host = self.network_interface[0].access_config[0].nat_ip
  }

  network_interface {
    network = var.network_self_link
    access_config {}
  }

  # Need to create the directory first, since opentofu does funny stuff otherwise
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /var/chirpstack"
    ]
  }
  # Copy the local file with the credentials to the remote machine
  provisioner "file" {
    source = local_file.chirpstack_env.filename
    destination = "/var/chirpstack/chirpstack.env"
  }

  # Copy ca certificate from postgres deployment into remote machine
  # to allow for secure connections to the postgres machine 
  provisioner "file" {
    source      = local_file.ca_cert.filename
    destination = "/var/chirpstack/ca-certificate.crt"
  }

  # provisioner "file" {
  #   source = local_file.chirpstack_gateway_env.filename
  #   destination = "/var/chirpstack/chirpstack-gateway-bridge.env"
  # }
  provisioner "remote-exec" {
    inline = [
      <<-EOT
        bash -c 'set -eux

        export DEBIAN_FRONTEND=noninteractive
        export NEEDRESTART_MODE=a

        echo "⏳ Waiting for dpkg lock"
        for i in {1..20}; do
          fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || break
          echo "🔒 apt lock held, waiting 3s..."
          sleep 3
        done

        echo "🔁 apt-get update"
        for i in {1..5}; do
          apt-get update -y && break || {
            echo "❌ apt-get update failed, retrying..."
            sleep 5
          }
        done

        echo "📦 Installing Docker dependencies"
        for i in {1..5}; do
          apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git && break || {
            echo "❌ apt install failed, retrying..."
            sleep 5
          }
        done

        echo "🔑 Adding Docker GPG key"
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor \
          -o /usr/share/keyrings/docker-archive-keyring.gpg

        echo "📋 Adding Docker repo"
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null

        echo "🔁 apt-get update (Docker repo)"
        for i in {1..5}; do
          apt-get update -y && break || {
            echo "❌ apt-get update (docker) failed, retrying..."
            sleep 5
          }
        done

        echo "🐳 Installing Docker"
        for i in {1..5}; do
          apt-get install -y docker-ce docker-ce-cli containerd.io && break || {
            echo "❌ Docker install failed, retrying..."
            sleep 5
          }
        done

        echo "🧩 Enabling Docker service"
        systemctl enable docker
        systemctl start docker

        echo "🔧 Installing legacy docker-compose"
        curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

        echo "📥 Cloning ChirpStack"
        git clone https://github.com/tofuhubhq/chirpstack-docker.git /opt/chirpstack

        echo "⏳ Waiting for Docker daemon to be ready..."
        for i in {1..20}; do
          docker info >/dev/null 2>&1 && break
          echo "🐋 Docker not ready yet, retrying in 3s..."
          sleep 3
        done

        echo "🚀 Starting ChirpStack via docker-compose"
        cd /opt/chirpstack
        docker-compose up --build -d
        '
      EOT
    ]
  }
}

output "chirpstack_instance_ips" {
  value = [for i in google_compute_instance.chirpstack : i.network_interface[0].access_config[0].nat_ip]
}
