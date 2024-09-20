variable "ip" {
  description = "ip address of the master"
}

variable "domain" {
  description = "Domain name"
}

variable "TLS_name" {
  description = "TLS certificate name, same as domain but with dashes instead of points"
}

variable "TLS_email" {
  description = "Email address used to register TLS certificate"
}

variable "mem_alloc_gb" {
  description = "RAM allocation per user"
}

variable "cpu_alloc" {
  description = "CPU allocation per user (floating point values are supported)"
}

variable "admin_user" {
  description = "User with root access"
}

variable "binder_version" {
  description = "binderhub helm chart version - https://jupyterhub.github.io/helm-chart/#development-releases-binderhub"
}

variable "docker_registry" {
  description = "Docker registry url"
  default     = "docker.io"
}

variable "docker_id" {
  description = "Docker hub username"
}

variable "docker_password" {
  description = "Docker hub password"
}

variable "cloudflare_token" {
  description = "Cloudflare token."
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
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
}

variable "prometheus_subdomain" {
  description = "Prometheus subdomain (e.g. <<prometheus>>.example.org)"
  type        = string
}