variable "do_access_token" {
  description = "Digital ocean access token"
  type        = string
}

variable "do_project_id" {
  description = "Digital ocean project id"
  type        = string
}

variable "do_db_name" {
  description = "Digital ocean db name"
  type        = string
}

variable "do_db_engine" {
  description = "Digital ocean db engine"
  type        = string
}

variable "do_db_version" {
  description = "Digital ocean db version"
  type        = string
}

variable "do_db_size" {
  description = "Digital ocean db size"
  type        = string
}

variable "do_db_region" {
  description = "Digital ocean db region"
  type        = string
}

variable "do_db_node_count" {
  description = "Digital ocean db node count"
  type        = string
}

provider "digitalocean" {
  token = var.do_access_token
}

resource "digitalocean_database_cluster" "postgres" {
  name       = var.do_db_name
  engine     = var.do_db_engine
  version    = var.do_db_version
  size       = var.do_db_size
  region     = var.do_db_region
  node_count = var.do_db_node_count
  project_id = var.do_project_id
}

# Create the pg_trgm extension
resource "null_resource" "enable_pg_trgm" {
  depends_on = [
    digitalocean_database_cluster.postgres
  ]
  provisioner "local-exec" {
    command = <<EOT
PGPASSWORD=${digitalocean_database_cluster.postgres.password} \
psql "host=${digitalocean_database_cluster.postgres.host} \
port=${digitalocean_database_cluster.postgres.port} \
user=${digitalocean_database_cluster.postgres.user} \
dbname=${digitalocean_database_cluster.postgres.database} \
sslmode=require" \
-c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
EOT
  }
}


resource "digitalocean_database_firewall" "whitelist_chirpstack_tag" {
  cluster_id = digitalocean_database_cluster.postgres.id

  rule {
    type  = "tag"
    value = "chirpstack"  # This must match the tag used on your droplets
  }

  # Optional: allow your local IP for debugging
  # rule {
  #   type  = "ip_addr"
  #   value = "203.0.113.10"
  # }
}

output "postgres_credentials" {
  value = {
    host     = digitalocean_database_cluster.postgres.host
    port     = digitalocean_database_cluster.postgres.port
    user     = digitalocean_database_cluster.postgres.user
    password = digitalocean_database_cluster.postgres.password
    uri      = digitalocean_database_cluster.postgres.uri
    db_name  = digitalocean_database_cluster.postgres.database
  }
  sensitive = true
}

data "digitalocean_database_ca" "this" {
  cluster_id = digitalocean_database_cluster.postgres.id
}

output "ca_certificate" {
  value = data.digitalocean_database_ca.this.certificate
}