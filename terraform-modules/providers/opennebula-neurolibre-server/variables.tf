variable "one_endpoint" {
  description = "OpenNebula API endpoint"
  type        = string
}

variable "one_username" {
  description = "OpenNebula username"
  type        = string
}

variable "one_password" {
  description = "OpenNebula password"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "new_relic_api" {
  description = "New Relic API key"
  type        = string
  sensitive   = true
}

variable "new_relic_account" {
  description = "New Relic account ID"
  type        = string
}

variable "image_name" {
  description = "Name of the OpenNebula image to use"
  type        = string
}

variable "network_name" {
  description = "Name of the OpenNebula virtual network to use"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "server_flavor" {
  description = "Server flavor/size"
  type        = string
}

variable "template_id" {
  description = "ID of the OpenNebula template to use"
  type        = string
}

variable "cpu" {
  description = "Number of CPUs for the VM"
  type        = number
}

variable "vcpu" {
  description = "Number of vCPUs for the VM"
  type        = number
}

variable "memory" {
  description = "Amount of memory for the VM (in MB)"
  type        = number
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key file"
  type        = string
}

variable "instance_volume_size" {
  description = "Size of the instance volume in GB"
  type        = number
}

variable "ssh_authorized_keys" {
  description = "List of SSH public keys to authorize"
  type        = list(string)
}

variable "volume_mount_point" {
  description = "Mount point for the additional volume"
  type        = string
}

variable "api_username" {
  description = "API username"
  type        = string
}

variable "api_password" {
  description = "API password"
  type        = string
  sensitive   = true
}

variable "server_domain" {
  description = "Domain for the server"
  type        = string
}

variable "server_subdomain" {
  description = "Subdomain for the server"
  type        = string
}

variable "admin_email" {
  description = "Admin email"
  type        = string
  sensitive   = true
} 