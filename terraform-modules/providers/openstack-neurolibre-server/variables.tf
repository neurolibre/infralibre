variable "project_name" {
  description = "Unique project name that is used to name resources on openstack (e.g. neurolibre-preview-server, neurolibre-preprint-volume, etc)."
  type        = string
  default     = "neurolibre"
}

variable "instance_volume_size" {
  description = "Volume size that will be attached to the var.volume_point_dir on this server. This will not be used if var.existing_volume_uuid is set."
  type        = number
  default     = 100
}

variable "os_flavor_server" {
  description = "The list of flavors that can be used to create the server (available on the openstack project portal)."
  type        = string
  default = "c8-30gb-186"
}

variable "image_name" {
  description = "The name of the (Ubuntu, do not use kvm kernel) image that will be used to create the server."
  type = string
  default = "Ubuntu-24.04-Noble-x64-2024-05"
}

variable "server_flavor" {
  description = "Determines the type of neurolibre server: preview or preprint."
  type = string
  default = "preview"
}

variable "existing_volume_uuid" {
  description = "UUID of an existing volume to attach to the server. If not set (default), a new volume will be created with var.instance_volume_size storage capacity."
  type        = string
  default     = ""
}

variable "volume_mount_point" {
  description = "Mount point for the volume."
  type        = string
  default     = "/DATA"
}

variable "cc_private_network" {
  description = "Private network to join. Check openstack project portal to see available networks."
  default = "def-pbellec-neurolibre-network"
}

variable "nfs_secgroup_name" {
  description = "A security group name that already exists on the nfs server."
  default = "neurolibre-test-secgroup"
}

variable "nfs_ip_address" {
  description = "Internal IP address of the NFS instance on openstack."
  type = string
  default = "192.168.73.179"
}

variable "nfs_mnt_dir" {
  description = "Directory on the node where NFS will be mounted."
  type = string
  default = "/DATA_NFS"
}

variable "public_network" {
  description = "Public network to use for the server. Check openstack project portal to see available networks."
  type = string
  default = "Public-Network"
}

variable "existing_keypair_name" {
  description = "Name of the existing keypair to use"
  type        = string
}

variable "api_username" {
  description = "Username for the API"
  type        = string
  sensitive   = true
}

variable "api_password" {
  description = "Password for the API"
  type        = string
  sensitive   = true
  }

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "server_domain" {
  description = "Domain name for the server"
  type        = string
  default = "neurolibre.org"
}

variable "server_subdomain" {
  description = "The subdomain of the server (xxx.{var.server_domain}) that will be registered in Cloudflare as an A record. Make sure that this subdomain DOES NOT already exist in Cloudflare as it will cause a conflict."
  type        = string
  default = "preprint2"
}

variable "ssh_authorized_keys" {
  description = "List of public SSH keys that can connect to the server."
  type        = list(string)
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "ssh_private_key" {
  description = "Path to the private SSH key on your local machine that will be used to connect to the server (e.g., ~/.ssh/id_rsa)."
  type        = string
  sensitive   = true
}