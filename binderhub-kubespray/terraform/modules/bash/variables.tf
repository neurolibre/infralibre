# Vars for install-binderhub-and-monitoring.sh
variable "cloudflare_api_token" {
  description = "Cloudflare API token (if needed by script)."
  type        = string
  sensitive   = true
}
variable "binderhub_version" {
  description = "Version tag for BinderHub."
  type        = string
}
variable "cluster_name" {
  description = "Name of the cluster."
  type        = string
}
variable "admin_user" {
  description = "Admin username on nodes."
  type        = string
}
variable "worker_count" {
  description = "Number of worker nodes."
  type        = number
}

# Vars for allow-pod-packets.sh
variable "kube_service_addresses" {
  description = "CIDR for Kubernetes services."
  type        = string
}
variable "kube_pods_subnet" {
  description = "CIDR for Kubernetes pods."
  type        = string
}
variable "security_group_id" {
  description = "ID of the OpenStack security group for the cluster."
  type        = string
}
variable "load_balancer_ip" {
  description = "Floating IP used for the load balancer."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key for Ansible."
  type        = string
}

variable "kubespray_version_branch" {
  description = "Release branch of Kubespray to install from."
  type        = string
}

variable "is_load_balancer" {
  description = "Whether to create a load balancer metallb."
  type        = bool
}

variable "is_calico_rr" {
  description = "Whether to use Calico RR for MetalLB."
  type        = bool
  default     = false
}
