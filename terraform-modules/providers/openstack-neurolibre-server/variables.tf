variable "instance_volume_size" {
  description = "Volume size for each instance"
}

variable "ssh_authorized_keys" {
  description = "List of public SSH keys that can connect to the cluster"
  type        = list(string)
  sensitive   = true
}

variable "os_flavor_server" {
  description = "OS base image"
}

variable "project_name" {
  description = "Unique project name"
}

variable "server_flavor" {
  description = "Preview or preprint"
}

variable "existing_volume_uuid" {
  description = "UUID of an existing volume to use, if any"
  type        = string
  default     = ""
}

variable "volume_mount_point" {
  description = "Mount point for the volume"
  type        = string
  default     = "/DATA"
}

variable "image_name" {
  description = "Disk image name"
}

variable "cc_private_network" {
  description = "Private network to join (must be set on ComputeCanada)"
  default     = ""
}

variable "nfs_secgroup_name" {
  description = "A security group name that already exists on the sftp server."
}

variable "nfs_ip_address" {
  description = "Internal IP address of the NFS instance on openstack."
}

variable "nfs_mnt_dir" {
  description = "Directory on the node where NFS will be mounted."
}

variable "public_network" {
  default  = "Public-Network"
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

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
  sensitive   = true
}

variable "cloudflare_hostname" {
  description = "Hostname for the Cloudflare origin certificate"
  type        = string
}