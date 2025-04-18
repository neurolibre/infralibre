    # Vars for install-binderhub-and-monitoring.sh
    variable "cloudflare_token" {
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

    # Vars for allow-pod-pockets.sh
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
