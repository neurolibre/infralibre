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

variable "ssh_private_key_path" {
  description = "Path to the private SSH key (on your local machine) for provisioning"
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

variable "public_network_name" {
  description = "Name of the existing public network"
  default     = "Public-Network"
  type        = string
}

variable "internal_network_name" {
  description = "Name of the existing internal network"
  default     = "def-xxx-xxx"
  type        = string
}

variable "internal_subnet_name" {
  description = "Name of the existing subnet"
  default     = "def-xxx-xxx"
  type        = string
}

variable "main_domain" {
  description = "Main domain to be used for the BinderHub, JupyterHub, Grafana, and Prometheus services."
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

variable "kube_service_addresses" {
  description = "Kubernetes service addresses"
  type        = string
  default     = "10.233.0.0/18"
}

variable "kube_pods_subnet" {
  description = "Kubernetes pods subnet"
  type        = string
  default     = "10.233.64.0/18"
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

variable "cloudflare_api_token" {
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

variable "db_cinder_zone" {
  description = "Cinder zone"
  type        = string
  default     = "nova"
}

variable "kubespray_version_branch" {
  description = "Release branch of Kubespray to install from."
  type        = string
}

variable "k8s_version" {
  description = "Version of Kubernetes to install."
  type        = string
}

variable "is_load_balancer" {
  description = "Whether to create attempt to create a load balancer metallb."
  type        = bool
}

variable "is_calico_rr" {
  description = "Whether to create a calico route reflector. Takes effect only if is_load_balancer is true."
  type        = bool
  default     = false
}

variable "ceph_rule_name" {
  description = "<<Access to>> indicated in the share access rule linked to the share."
  type        = string
}

variable "ceph_rule_key" {
  description = "<<Access key>> indicated in the share access rule linked to the share."
  type        = string
  sensitive   = true
}


variable "ceph_share_hash" {
  description = "Hash indicated in the Path target of the share as in ...,...,...:/volumes/_nogroup/<<hash>>"
  type        = string
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
  description = "Directory to mount the shared data (cephfs)."
  type        = string
}
