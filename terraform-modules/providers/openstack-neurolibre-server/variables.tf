variable "project_name" {
  description = "Unique project name that is used to name resources on openstack (e.g. neurolibre-preview-server, neurolibre-preprint-volume, etc)."
  type        = string
}

variable "instance_volume_size" {
  description = "Volume size that will be attached to the var.volume_point_dir on this server."
  type        = number
}

variable "external_volume_size" {
  description = "Volume size that will be attached to the var.volume_point_dir on this server. This will not be used if var.existing_volume_uuid is set."
  type        = number
}

variable "os_flavor_server" {
  description = "The list of flavors that can be used to create the server (available on the openstack project portal)."
  type        = string
}

variable "image_name" {
  description = "The name of the (Ubuntu, do not use kvm kernel) image that will be used to create the server."
  type = string
}

variable "server_flavor" {
  description = "Determines the type of neurolibre server: preview or preprint."
  type = string

  validation {
    condition     = contains(["preprint", "preview"], var.server_flavor)
    error_message = "The server_flavor must be either 'preprint' or 'preview'."
  }
}

variable "existing_volume_uuid" {
  description = "UUID of an existing volume to attach to the server. If not set (default), a new volume will be created with var.instance_volume_size storage capacity."
  type        = string
}

variable "volume_mount_point" {
  description = "Mount point for the volume."
  type        = string
}

variable "cc_private_network" {
  description = "Private network to join. Check openstack project portal to see available networks."
  type = string
}

variable "nfs_secgroup_name" {
  description = "A security group name that already exists on the nfs server."
  type = string
}

variable "nfs_server_ip" {
  description = "Internal IP address of the NFS instance on openstack."
  type = string
}

variable "nfs_source_dir" {
  description = "Directory on the NFS server that will be mounted on the neurolibre server."
  type = string
}

variable "nfs_mnt_dir" {
  description = "Directory on the neurolibre server where NFS will be mounted."
  type = string
}

variable "public_network" {
  description = "Public network to use for the server. Check openstack project portal to see available networks."
  type = string
}

variable "existing_keypair_name" {
  description = "The name of the existing keypair registered in openstack that can let you connect to the server in case var.ssh_authorized_keys cannot be set successfully."
  type        = string
}

variable "server_domain" {
  description = "Domain name for the server"
  type        = string
}

variable "server_subdomain" {
  description = "The subdomain of the server (xxx.{var.server_domain}) that will be registered in Cloudflare as an A record. Make sure that this subdomain DOES NOT already exist in Cloudflare as it will cause a conflict."
  type        = string
}

variable "ssh_authorized_keys" {
  description = "List of public SSH keys that can connect to the server."
  type        = list(string)
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID."
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with the necessary permissions to update the DNS records and create TLS/SSL certificates."
  type        = string
  sensitive   = true
}

variable "ssh_private_key" {
  description = "Path to the private SSH key on your local machine that will be used to connect to the server (e.g., ~/.ssh/id_rsa)."
  type        = string
  sensitive   = true
}

variable "api_username" {
  description = "Username for the Flask API (subdomain.neurolibre.org/api)."
  type        = string
  sensitive   = true
}

variable "api_password" {
  description = "Password for the Flask API (subdomain.neurolibre.org/api)."
  type        = string
  sensitive   = true
  }

variable "new_relic_api" {
  description = "New Relic API key."
  type        = string
  sensitive   = true
}

variable "new_relic_account" {
  description = "New Relic account ID."
  type        = string
  sensitive   = true
}

variable "new_relic_license" {
  description = "New Relic license key."
  type        = string
  sensitive   = true
}

variable "admin_email" {
  description = "Admin email for Newrelic."
  type        = string
  sensitive   = true
}