
variable "do_access_token" {
  description = "Digital ocean access token"
  type        = string
}
variable "do_domain" {
  description = "Domain"
  type        = string
}

variable "do_loadbalancer_region" {
  description = "Digital ocean loadbalancer name"
  type        = string
  default     = ""
}
variable "droplet_ids" {
  description = "List of droplet IDs to attach to the load balancer"
  type        = list(string)
}
variable "do_project_id" {
  description = "Digital ocean project id"
  type        = string
  default     = ""
}
variable "do_chirpstack_droplet_region" {
  description = "Digital ocean droplet region"
  type        = string
  default     = ""
}

variable "do_loadbalancer_name" {
  description = "Digital ocean loadbalancer name"
  type        = string
  default     = ""
}

variable "domain_depends_on" {
  description = "Dummy variable to enforce domain creation order"
  type        = string
  default     = ""
}

variable "do_lorawan_subdomain" {
  description = "Lorawan subdomain"
  type        = string
  default     = ""
}

provider "digitalocean" {
  token = var.do_access_token
}

resource "digitalocean_loadbalancer" "chirpstack_lb" {
  name       = var.do_loadbalancer_name
  region     = var.do_chirpstack_droplet_region
  project_id = var.do_project_id
  droplet_ids = var.droplet_ids

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"
    target_port    = 8080
    target_protocol = "http"
  }

  healthcheck {
    protocol = "http"
    port     = 8080
    path     = "/"
  }

  redirect_http_to_https = false
}

resource "digitalocean_record" "chirpstack_dns" {
  domain = var.do_domain
  type   = "A"
  name   = var.do_lorawan_subdomain
  value  = digitalocean_loadbalancer.chirpstack_lb.ip

  depends_on = [digitalocean_loadbalancer.chirpstack_lb]
}

# Wait for DNS to propagate + create cert via doctl
resource "null_resource" "create_tls_cert" {
  depends_on = [digitalocean_record.chirpstack_dns]

  provisioner "local-exec" {
    environment = {
      DIGITALOCEAN_ACCESS_TOKEN = var.do_access_token
    }

    command = <<-EOT
      bash -c '
        echo "🔍 Waiting for DNS to propagate..."
        for i in {1..30}; do
          resolved_ip=$(dig +short ${var.do_lorawan_subdomain}.${var.do_domain})
          echo "Resolved: $resolved_ip"
          if [ "$resolved_ip" = "${digitalocean_loadbalancer.chirpstack_lb.ip}" ]; then
            echo "✅ DNS OK"
            break
          fi
          sleep 10
        done

        echo "📜 Creating TLS cert via doctl..."
        doctl compute certificate create --name lns-cert-${var.do_lorawan_subdomain} --type lets_encrypt --dns-names ${var.do_lorawan_subdomain}.${var.do_domain}
      '
    EOT
  }
}

resource "null_resource" "patch_lb_with_cert" {
  depends_on = [null_resource.create_tls_cert]

  provisioner "local-exec" {
    environment = {
      DIGITALOCEAN_ACCESS_TOKEN = var.do_access_token
    }

    command = <<EOT
bash -c '
set -e

echo "🔁 Patching load balancer with TLS cert..."

LB_ID="${digitalocean_loadbalancer.chirpstack_lb.id}"
LB_NAME="${digitalocean_loadbalancer.chirpstack_lb.name}"
REGION="${digitalocean_loadbalancer.chirpstack_lb.region}"
DROPLET_IDS="${join(",", var.droplet_ids)}"
CERT_ID=$(doctl compute certificate list --format ID,Name | grep lns-cert-${var.do_lorawan_subdomain} | awk '"'"'{print $1}'"'"')

# Retry loop to wait until cert is usable
for i in {1..10}; do
  CERT_ID=$(doctl compute certificate list --format ID,Name,State | grep "$CERT_NAME" | awk '"'"'$3 == "verified" {print $1}'"'"')
  if [ -n "$CERT_ID" ]; then
    echo "✅ Found verified certificate: $CERT_ID"
    break
  fi
  echo "⏳ Waiting for certificate to be ready... ($i/10)"
  sleep 5
done

if [ -z "$CERT_ID" ]; then
  echo "❌ Certificate '$CERT_NAME' not found or not verified"
  exit 1
fi

echo "📄 Using cert ID: $CERT_ID"
echo "📦 Updating load balancer..."

doctl compute load-balancer update --help
doctl compute load-balancer update "$LB_ID" --region "$REGION" --name "$LB_NAME" --droplet-ids "$DROPLET_IDS" --forwarding-rules "entry_protocol:http,entry_port:80,target_protocol:http,target_port:8080" --forwarding-rules "entry_protocol:https,entry_port:443,target_protocol:http,target_port:8080,certificate_id:$CERT_ID" --health-check "protocol:http,port:8080,path:/,check_interval_seconds:10,response_timeout_seconds:5,healthy_threshold:5,unhealthy_threshold:3" --redirect-http-to-https'
EOT
  }
}