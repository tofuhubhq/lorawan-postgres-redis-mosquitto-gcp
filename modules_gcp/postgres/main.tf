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

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

resource "google_sql_database_instance" "postgres" {
  name             = var.db_name
  database_version = "POSTGRES_14"
  region           = var.gcp_region

  settings {
    tier = var.db_tier
  }
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
