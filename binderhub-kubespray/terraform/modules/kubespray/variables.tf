    variable "cluster_name" {
      description = "Name of the Kubernetes cluster."
      type        = string
    }

    variable "admin_user" {
      description = "Admin username for the nodes."
      type        = string
    }

    variable "master_floating_ip" {
      description = "Floating IP of the master node."
      type        = string
    }

    variable "master_private_ip" {
      description = "Private IP of the master node."
      type        = string
    }

    variable "worker_private_ips" {
      description = "List of private IPs of the worker nodes."
      type        = list(string)
    }

    variable "kube_service_addresses" {
      description = "CIDR for Kubernetes services."
      type        = string
    }

    variable "kube_pods_subnet" {
      description = "CIDR for Kubernetes pods."
      type        = string
    }

    # Inputs from openstack_network module outputs
    variable "openstack_internal_network_id" {
      description = "ID of the internal OpenStack network (used as subnet ID in template)."
      type        = string
    }

    variable "openstack_public_network_id" {
      description = "ID of the public OpenStack network."
      type        = string
    }

    # Add any other variables needed by the Kubespray templates