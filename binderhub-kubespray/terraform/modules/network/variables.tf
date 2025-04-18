variable "public_network_name" {
  description = "Name of the existing public OpenStack network."
  type        = string
}

variable "internal_network_name" {
  description = "Name of the existing internal OpenStack network."
  type        = string
}

variable "cluster_name" {
  description = "Name of the cluster, used for naming resources."
  type        = string
}