variable "gcp_project" { type = string }
variable "gcp_region" { type = string }
variable "instance_ips" { type = list(string) }
variable "lb_name" { type = string }

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

resource "google_compute_health_check" "http" {
  name               = "${var.lb_name}-hc"
  check_interval_sec = 10
  http_health_check {
    port = 8080
  }
}

resource "google_compute_instance_group" "group" {
  name    = "${var.lb_name}-group"
  zone    = "${var.gcp_region}-a"

  instances = [for ip in var.instance_ips : ip]

  named_port {
    name = "http"
    port = 8080
  }
}

resource "google_compute_backend_service" "default" {
  name                    = "${var.lb_name}-backend"
  protocol                = "HTTP"
  health_checks           = [google_compute_health_check.http.id]
  timeout_sec             = 10
  port_name               = "http"
  connection_draining_timeout_sec = 0
  backend {
    group = google_compute_instance_group.group.self_link
  }
}

resource "google_compute_url_map" "map" {
  name            = "${var.lb_name}-map"
  default_service = google_compute_backend_service.default.self_link
}

resource "google_compute_target_http_proxy" "proxy" {
  name   = "${var.lb_name}-proxy"
  url_map = google_compute_url_map.map.self_link
}

resource "google_compute_global_forwarding_rule" "fr" {
  name       = "${var.lb_name}-fr"
  target     = google_compute_target_http_proxy.proxy.self_link
  port_range = "80"
}

output "lb_ip" {
  value = google_compute_global_forwarding_rule.fr.ip_address
}
