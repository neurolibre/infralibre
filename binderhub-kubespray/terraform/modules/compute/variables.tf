variable "cluster_name" {
  description = "Name of the cluster, used for naming resources."
  type        = string
}

variable "image_name" {
  description = "Name of the OpenStack image to use for instances."
  type        = string
}

variable "flavor_master" {
  description = "OpenStack flavor for the master node."
  type        = string
}

variable "flavor_worker" {
  description = "OpenStack flavor for the worker nodes."
  type        = string
}

variable "worker_count" {
  description = "Number of worker nodes to create."
  type        = number
}

variable "ssh_authorized_keys" {
  description = "List of public SSH keys to authorize on the instances."
  type        = list(string)
  sensitive   = true
}

variable "ssh_private_key_path" {
  description = "Path to the private SSH key (on your local machine) for provisioning"
  type        = string
}

variable "admin_user" {
  description = "The default admin user created on the instances (used in cloud-init template)."
  type        = string
  default     = "ubuntu" # Or make this required if it varies
}

variable "cinder_volume_size" {
  description = "Size of the Cinder volume for hub-db in GB."
  type        = number
  default     = 1
}

variable "cinder_availability_zone" {
  description = "Availability zone for the Cinder volume."
  type        = string
}

# --- Inputs from other modules ---

variable "network_security_group_ids" {
  description = "List of security group IDs to attach to the instances."
  type        = list(string)
}

variable "network_master_port_id" {
  description = "ID of the pre-created network port for the master node."
  type        = string
}

variable "network_internal_id" {
  description = "ID of the internal network for worker nodes."
  type        = string
}

variable "network_public_pool_name" {
  description = "Name of the public network pool for allocating the floating IP."
  type        = string
}

variable "network_floating_ip" {
  description = "Floating IP address to associate with the master node."
  type        = string
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

