# Variables
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "worker_count" {
  description = "Number of worker nodes to create"
  type        = number
  default     = 1
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair to use"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the private SSH key for provisioning"
  type        = string
}

variable "image_name" {
  description = "OpenStack image name for instances"
  type        = string
}

variable "flavor_master" {
  description = "OpenStack flavor for master node"
  type        = string
}

variable "flavor_worker" {
  description = "OpenStack flavor for worker node"
  type        = string
}

variable "network_name" {
  description = "Name of the existing public network"
  default     = "Public-Network"
  type        = string
}

variable "subnet_name" {
  description = "Name of the existing subnet"
  default     = "def-xxx-xxx"
  type        = string
}

variable "binderhub_domain" {
  description = "Domain for BinderHub"
  type        = string
}

variable "grafana_domain" {
  description = "Domain for Grafana"
  type        = string
}

variable "binderhub_subdomain" {
  description = "Subdomain for BinderHub"
  default     = "binder"
}

variable "jupyterhub_subdomain" {
  description = "Subdomain for JupyterHub"
  default     = "hub"
}

variable "grafana_subdomain" {
  description = "Subdomain for Grafana"
  default     = "grafana"
}

variable "prometheus_subdomain" {
  description = "Subdomain for Prometheus"
  default     = "prometheus"
}

variable "registry_url" {
  description = "Docker registry URL"
  type        = string
}

variable "registry_username" {
  description = "Docker registry username"
  default     = "registry-user"
}

variable "registry_password" {
  description = "Docker registry password"
  type        = string
  sensitive   = true
}

variable "cloudflare_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "ssh_authorized_keys" {
  description = "List of public SSH keys that can connect to the cluster"
  type        = list(string)
  sensitive   = true
}

variable "binderhub_version" {
  description = "Version of BinderHub Helm chart to deploy"
  type        = string
  default     = "1.0.0-0.dev.git.3213.h6a5a5a0"
}

variable "email_contact" {
  description = "Email address for Let's Encrypt notifications and Cloudflare configuration"
  type        = string
  default     = "conp.dev@gmail.com"  # You might want to change this default or require it to be set
}

variable "admin_user" {
  description = "Username for the admin user"
  type = string
}

variable "cinder_zone" {
  description = "Cinder zone"
  type        = string
  default     = "nova"
}
