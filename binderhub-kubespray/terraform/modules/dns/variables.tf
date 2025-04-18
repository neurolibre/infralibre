variable "cloudflare_token" {
    description = "Cloudflare API Token"
    type        = string
    sensitive   = true
}

variable "cloudflare_zone_id" {
    description = "Cloudflare Zone ID"
    type        = string
    sensitive   = true
}

variable "binderhub_subdomain" {
    description = "BinderHub subdomain"
    type        = string
}

variable "jupyterhub_subdomain" {
    description = "JupyterHub subdomain"
    type        = string
}

variable "grafana_subdomain" {
    description = "Grafana subdomain"
    type        = string
}

variable "prometheus_subdomain" {
    description = "Prometheus subdomain"
    type        = string  
}

variable "ip" {
    description = "IP address of the master node"
    type        = string
}