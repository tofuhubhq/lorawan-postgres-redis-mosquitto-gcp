variable "gcp_project" {
  type = string
}

variable "gcp_region" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_tier" {
  type    = string
  default = "db-f1-micro"
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type = string
}

variable "gcp_zone" {
  description = "GCP compute zone"
  type        = string
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_zone
  credentials = file("/Users/tommaso/Downloads/tofuhub-95de5791f8fb.json")
}

resource "google_sql_database_instance" "postgres" {
  name             = var.db_name
  database_version = "POSTGRES_14"
  region           = var.gcp_region

  settings {
    tier = var.db_tier

    ip_configuration {
      ipv4_enabled = true

      authorized_networks {
        name  = "allow-chirpstack"
        value = "0.0.0.0/0"  # You can restrict this later
      }
    }
  }

}

resource "google_sql_ssl_cert" "client_cert" {
  common_name = "my-client-cert"
  instance    = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "default" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}

resource "google_sql_database" "db" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
}

output "postgres_host" {
  value = google_sql_database_instance.postgres.public_ip_address
}

output "postgres_port" {
  value = 5432
}

output "postgres_user" {
  value = google_sql_user.default.name
}

output "postgres_password" {
  value     = var.db_password
  sensitive = true
}

output "postgres_db_name" {
  value = google_sql_database.db.name
}
output "client_cert" {
  value = google_sql_ssl_cert.client_cert.cert
}

output "client_key" {
  value = google_sql_ssl_cert.client_cert.private_key
}

output "server_ca_cert" {
  value = google_sql_ssl_cert.client_cert.server_ca_cert
}