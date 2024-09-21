variable "image" {
    description = "Name of glance image to use"
    type = string
}

variable "project_name" {
    description = "prefix of openstack resources"
    default = "neurolibre"
    type = string
}

variable "instance_count" {
    description = "Number of servers to run.  If you change this you will need to set up some sort of data replication for the registry files."
    default = 1
    type = number
}

variable "cc_private_network" {
    default = "internal"
    type = string
}

variable "public_network" {
    default = "external"
    type = string
}

variable "flavor" {
    description = "Flavor of the instance (see openstack flavors)"
    type = string
}

variable "ssh_user" {
    default = "core"
}

variable "docker_registry_user" {
  description = "Username for docker registry"
  type = string
  sensitive = true
}

variable "docker_registry_password" {
  description = "Password for docker registry"
  type = string
  sensitive = true
}

variable "existing_keypair_name" {
  description = "Name of existing keypair to use"
} 

variable "existing_secgroup_name" {
  description = "Name of common secgroup to use"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type = string
  sensitive = true
}

variable "server_domain" {
  description = "Domain name of the server"
  type = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  type = string
  sensitive = true
} 

variable "host_src_path" {
  description = "Path to the host source directory where docker swarm sources will be copied"
}

variable "registry_local_volume" {
  description = "Path where the registry will be mounted on the server.This is where the large volumes will be mounted."
}

variable "traefik_subdomain" {
  description = "Traefik subdomain"
}

variable "docker_subdomain" {
  description = "Docker subdomain"
}

variable "existing_volume_uuid" {
  description = "UUID of an existing volume to attach to the server. If not set (default), a new volume will be created with var.instance_volume_size storage capacity."
  type        = string
}

variable "instance_volume_size" {
  description = "Volume size that will be attached to the var.volume_point_dir on this server. This will not be used if var.existing_volume_uuid is set."
  type        = number
}

variable "new_relic_api" {
  description = "New Relic API key"
  type = string
  sensitive = true
}

variable "new_relic_account" {
  description = "New Relic account ID"
  type = string
  sensitive = true
}

variable "new_relic_license" {
  description = "New Relic license key"
  type = string
  sensitive = true
}

variable "admin_email" {
  description = "Admin email for newrelic alerts"
  type = string
  sensitive = true
}