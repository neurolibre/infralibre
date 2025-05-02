variable "load_balancer_ip" {
  description = "The floating IP address to be used by MetalLB and Ingress."
  type        = string
}

variable "master_private_ip" {
  description = "Private IP of the master node (for MetalLB BGP peering)."
  type        = string
}

variable "registry_url" {
  description = "URL of the Docker registry."
  type        = string
  default     = ""
}

variable "registry_username" {
  description = "Username for the Docker registry."
  type        = string
  default     = ""
  sensitive   = true
}

variable "registry_password" {
  description = "Password for the Docker registry."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cinder_db_volume_id" {
  description = "ID of the Cinder volume for the Hub DB persistent volume."
  type        = string
}

variable "main_domain" {
  description = "Main domain to be used for the BinderHub, JupyterHub, Grafana, and Prometheus services."
  type        = string
}

variable "binderhub_subdomain" {
  description = "Subdomain for BinderHub service."
  type        = string
}

variable "jupyterhub_subdomain" {
  description = "Subdomain for JupyterHub service."
  type        = string
}

variable "binderhub_version" {
  description = "Version tag for BinderHub deployment."
  type        = string
}

variable "cluster_name" {
  description = "Name of the cluster."
  type        = string
}

variable "email_contact" {
  description = "Email address for Let's Encrypt certificate notifications."
  type        = string
}

variable "grafana_subdomain" {
  description = "Subdomain for Grafana."
  type        = string
}

variable "prometheus_subdomain" {
  description = "Subdomain for Prometheus."
  type        = string
}

variable "is_load_balancer" {
  description = "Whether to create attempt to create a load balancer metallb."
  type        = bool
}

variable "binderhub_evidence_type" {
  description = "preview or preprint"
  type        = string

  validation {
    condition     = var.binderhub_evidence_type == "preview" || var.binderhub_evidence_type == "preprint"
    error_message = "The binderhub_evidence_type must be either 'preview' or 'preprint'."
  }
}

variable "shared_data_directory" {
  description = "Directory for shared data (assuming a folder under / e.g., if /DATA, set this to DATA)"
  type        = string
}
