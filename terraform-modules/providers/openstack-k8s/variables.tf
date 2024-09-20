variable "nb_nodes" {
  description = "Number of nodes"
}

variable "instance_volume_size" {
  description = "Volume size for each instance"
}

variable "ssh_authorized_keys" {
  description = "List of public SSH keys that can connect to the cluster"
  type        = list(string)
  sensitive   = true
}

variable "os_flavor_node" {
  description = "Node flavor"
}

variable "os_flavor_master" {
  description = "Master flavor"
}

variable "admin_user" {
  description = "User with root access (provider module output)"
  default     = "ubuntu"
}

variable "project_name" {
  description = "Unique project name"
}

variable "image_name" {
  description = "Disk image name"
}

variable "is_computecanada" {
  description = "Set true if hosted on ComputeCanada"
  default     = false
}

variable "cc_private_network" {
  description = "Private network to join (must be set on ComputeCanada)"
  default     = ""
}

variable "docker_registry" {
  description = "Docker registry url"
  default     = "docker.io"
}

variable "sftp_secgroup_name" {
  description = "A security group name that already exists on the sftp server."
}

variable "sftp_ip_address" {
  description = "Internal IP address of the SFTP instance on openstack."
}

variable "sftp_mnt_dir" {
  description = "Directory on the node where SFTP will be mounted."
}

variable "docker_id" {
  description = "Docker hub username"
  sensitive   = true
}

variable "docker_password" {
  description = "Docker hub password"
  sensitive   = true
}

variable "public_network" {
  default  = "Public-Network"
}

variable "ssh_private_key_path" {
  description = "Path to (on your local computer) where the private SSH key is stored."
  type        = string
  sensitive   = true
} 

variable "ssh_private_key_name" {
  description = "Name of the private SSH key file (on your local computer) pre-generated private SSH key whose public pair is distributed across nodes using the authorized_keys mechanism by cloud-init."
  type        = string
  sensitive   = true
} 