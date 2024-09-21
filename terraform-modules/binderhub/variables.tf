variable "ip" {
  description = "ip address of the master"
  type = string
}

variable "TLS_name" {
  description = "TLS certificate name, same as domain but with dashes instead of points"
  type = string
}

variable "TLS_email" {
  description = "Email address used to register TLS certificate"
  type = string
  sensitive = true
}

variable "mem_alloc_gb" {
  description = "RAM allocation per user"
  type = number
}

variable "cpu_alloc" {
  description = "CPU allocation per user (floating point values are supported)"
  type = number
}

variable "admin_user" {
  description = "User with root access"
  type = string
}

variable "binder_version" {
  description = "binderhub helm chart version - https://jupyterhub.github.io/helm-chart/#development-releases-binderhub"
  type = string
}

variable "docker_registry" {
  description = "Docker registry url"
  default     = "docker.io"
  type = string
}

variable "docker_id" {
  description = "Docker hub username"
  sensitive   = true
}

variable "docker_password" {
  description = "Docker hub password"
  sensitive   = true
}

variable "cloudflare_token" {
  description = "Cloudflare token."
  sensitive   = true
}

variable "binderhub_subdomain" {
  description = "Binderhub subdomain (e.g. <<binder>>.example.org)"
  type        = string
}

variable "binderhub_domain" {
  description = "Binderhub domain (e.g. example.org)"
  type        = string
}

variable "binder_deployment_yaml_config" {
  description = "config.yaml or prod-config.yaml"
  type        = string
}

variable "project_name" {
  description = "Project name (same as the project name used in the openstack provider)"
  type        = string
}

variable "grafana_subdomain" {
  description = "Grafana subdomain (e.g. <<grafana>>.example.org)"
  type        = string
}

variable "grafana_admin_user" {
  description = "Grafana admin user"
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "prometheus_subdomain" {
  description = "Prometheus subdomain (e.g. <<prometheus>>.example.org)"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  type        = string
  sensitive   = true
}