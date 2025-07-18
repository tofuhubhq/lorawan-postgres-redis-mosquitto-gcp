terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

# GCP variables
variable "gcp_project" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
}

variable "gcp_zone" {
  description = "GCP zone"
  type        = string
}

variable "network_name" {
  type        = string
  description = "VPC network name"
  default     = "lorawan-network"
}

variable "firewall_name" {
  type        = string
  default     = "ssh-firewall"
}

variable "redis_instance_name" {
  type = string
  default = "redis"
}

variable "redis_machine_type" {
  type    = string
  default = "e2-medium"
}

variable "redis_password" {
  type = string
}

variable "mosquitto_instance_name" {
  type    = string
  default = "mosquitto"
}

variable "mosquitto_machine_type" {
  type    = string
  default = "e2-medium"
}

variable "mosquitto_username" { type = string }
variable "mosquitto_password" { type = string }

variable "chirpstack_machine_type" {
  type    = string
  default = "e2-medium"
}

variable "chirpstack_count" {
  type    = number
  default = 2
}

variable "db_name" {
  type    = string
  default = "lorawan-db"
}

variable "db_user" {
  type    = string
  default = "lorawan"
}

variable "db_password" { type = string }

# Modules
module "network" {
  source          = "./modules_gcp/network"
  gcp_project     = var.gcp_project
  gcp_region      = var.gcp_region
  gcp_network_name = var.network_name
  gcp_firewall_name = var.firewall_name
}

module "redis" {
  source             = "./modules_gcp/redis"
  gcp_project        = var.gcp_project
  gcp_zone           = var.gcp_zone
  redis_instance_name = var.redis_instance_name
  machine_type        = var.redis_machine_type
  redis_password      = var.redis_password
  network_self_link   = module.network.network_self_link
}

module "postgres" {
  source      = "./modules_gcp/postgres"
  gcp_project = var.gcp_project
  gcp_region  = var.gcp_region
  db_name     = var.db_name
  db_user     = var.db_user
  db_password = var.db_password
}

module "mosquitto" {
  source               = "./modules_gcp/mosquitto"
  gcp_project          = var.gcp_project
  gcp_zone             = var.gcp_zone
  mosquitto_instance_name = var.mosquitto_instance_name
  machine_type            = var.mosquitto_machine_type
  mosquitto_username      = var.mosquitto_username
  mosquitto_password      = var.mosquitto_password
  network_self_link       = module.network.network_self_link
}

module "chirpstack" {
  source            = "./modules_gcp/chirpstack"
  gcp_project       = var.gcp_project
  gcp_zone          = var.gcp_zone
  instance_count    = var.chirpstack_count
  machine_type      = var.chirpstack_machine_type
  network_self_link = module.network.network_self_link
  mosquitto_host     = module.mosquitto.mosquitto_host
  mosquitto_port     = module.mosquitto.mosquitto_port
  mosquitto_username = var.mosquitto_username
  mosquitto_password = var.mosquitto_password
  postgres_host      = module.postgres.postgres_host
  postgres_port      = module.postgres.postgres_port
  postgres_db_name   = module.postgres.postgres_db_name
  postgres_user      = module.postgres.postgres_user
  postgres_password  = module.postgres.postgres_password
  redis_host         = module.redis.redis_host
  redis_password     = module.redis.redis_password
}

module "loadbalancer" {
  source        = "./modules_gcp/loadbalancer"
  gcp_project   = var.gcp_project
  gcp_region    = var.gcp_region
  instance_ips  = module.chirpstack.chirpstack_instance_ips
  lb_name       = "lorawan-lb"
}

output "loadbalancer_ip" {
  value = module.loadbalancer.lb_ip
}
