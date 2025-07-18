# 🛰️ ChirpStack Full Stack Deployment

Deploy a production-ready ChirpStack instance with all its core dependencies using OpenTofu. This package includes:

- **ChirpStack Network Server**
- **ChirpStack Application Server**
- **PostgreSQL** for persistent storage
- **Redis** for stream and device session caching
- **Mosquitto (MQTT Broker)** for device uplink/downlink messaging
- **Load Balancer** for routing external traffic

> ⚡ Deploy to Digital Ocean

## 🚀 Deploy to Google Cloud Platform

A new `main_gcp.tf` configuration and accompanying modules allow deploying the same stack on GCP. Configure your project ID, region and zone along with the machine sizes and credentials, then run `tofu init && tofu apply` in the repository root.
