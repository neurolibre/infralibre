provider "cloudflare" {
  api_token = var.cloudflare_token
}

# Cloudflare DNS records
resource "cloudflare_record" "domain" {
  count   = length([var.binderhub_subdomain, var.grafana_subdomain, var.prometheus_subdomain])
  zone_id = var.cloudflare_zone_id
  name    = [var.binderhub_subdomain, var.grafana_subdomain, var.prometheus_subdomain][count.index]
  content = openstack_networking_floatingip_v2.master_fip.address
  type    = "A"
  proxied = true
}

# Get details of an existing PUBLIC network
data "openstack_networking_network_v2" "network" {
  name     = var.network_name
  external = true
}

# Get details of an existing INTERNAL network
data "openstack_networking_network_v2" "subnet" {
  name = var.subnet_name
}

# Create a keypair for each SSH key provided
resource "openstack_compute_keypair_v2" "keypair" {
  count      = length(var.ssh_authorized_keys)
  name       = "${var.cluster_name}-keypair-ed25519-${count.index}"
  public_key = var.ssh_authorized_keys[count.index]
}

# Create security group for Kubernetes
resource "openstack_networking_secgroup_v2" "k8s_secgroup" {
  name        = "${var.cluster_name}-secgroup"
  description = "Security group for Charmed Kubernetes cluster"
}

# Allow all internal traffic between cluster nodes
resource "openstack_networking_secgroup_rule_v2" "k8s_secgroup_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_group_id   = openstack_networking_secgroup_v2.k8s_secgroup.id
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
}

# Allow SSH from anywhere
resource "openstack_networking_secgroup_rule_v2" "k8s_secgroup_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
}

# Allow HTTPS from anywhere
resource "openstack_networking_secgroup_rule_v2" "k8s_secgroup_https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
}

# Allow HTTP from anywhere (for initial setup)
resource "openstack_networking_secgroup_rule_v2" "k8s_secgroup_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
}

# Create a PORT for the master node
resource "openstack_networking_port_v2" "master" {
  name               = "${var.cluster_name}-master"
  admin_state_up     = "true"
  network_id         = data.openstack_networking_network_v2.subnet.id
  security_group_ids = [openstack_networking_secgroup_v2.k8s_secgroup.id]
}

# Create ports for worker nodes
resource "openstack_networking_port_v2" "worker" {
  count              = var.worker_count
  name               = "${var.cluster_name}-worker-${count.index}"
  admin_state_up     = "true"
  network_id         = data.openstack_networking_network_v2.subnet.id
  security_group_ids = [openstack_networking_secgroup_v2.k8s_secgroup.id]
}

data "template_file" "cloud_init_master" {
  template = file("${path.module}/templates/cloud-init-master.yaml.tpl")
  vars = {
    ssh_authorized_keys = indent(2, join("\n", formatlist("- %s", var.ssh_authorized_keys)))
    admin_user          = var.admin_user
    juju_version        = "3.1/stable"
  }
}

data "template_file" "cloud_init_worker" {
  template = file("${path.module}/templates/cloud-init-worker.yaml.tpl")
  vars = {
    ssh_authorized_keys = indent(2, join("\n", formatlist("- %s", var.ssh_authorized_keys)))
    admin_user          = var.admin_user
  }
}

data "template_cloudinit_config" "master_config" {
  part {
    filename     = "master.yaml"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init_master.rendered
  }
}

data "template_cloudinit_config" "worker_config" {
  part {
    filename     = "worker.yaml"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init_worker.rendered
  }
}

# Master node
resource "openstack_compute_instance_v2" "master" {
  name            = "${var.cluster_name}-master"
  image_name      = var.image_name
  flavor_name     = var.flavor_master
  key_pair        = openstack_compute_keypair_v2.keypair[0].name
  security_groups = [openstack_networking_secgroup_v2.k8s_secgroup.name]
  user_data       = data.template_cloudinit_config.master_config.rendered

  network {
    port = openstack_networking_port_v2.master.id
  }

  metadata = {
    role = "master"
  }
}

# Create worker instances
resource "openstack_compute_instance_v2" "worker" {
  count           = var.worker_count
  name            = "${var.cluster_name}-worker-${count.index}"
  image_name      = var.image_name
  flavor_name     = var.flavor_worker
  key_pair        = openstack_compute_keypair_v2.keypair[0].name
  security_groups = [openstack_networking_secgroup_v2.k8s_secgroup.name]
  user_data       = data.template_cloudinit_config.worker_config.rendered

  network {
    port = openstack_networking_port_v2.worker[count.index].id
  }

  metadata = {
    role = "worker"
  }
}

# Floating IPs
resource "openstack_networking_floatingip_v2" "master_fip" {
  pool = data.openstack_networking_network_v2.network.name
}

resource "openstack_compute_floatingip_associate_v2" "master_fip_associate" {
  floating_ip = openstack_networking_floatingip_v2.master_fip.address
  instance_id = openstack_compute_instance_v2.master.id
}

# Generate Juju configuration
resource "local_file" "juju_config" {
  content = templatefile("${path.module}/templates/juju-config.yaml.tpl", {
    openstack_auth_url      = data.external.openstack_env.result["OS_AUTH_URL"]
    openstack_username      = data.external.openstack_env.result["OS_USERNAME"]
    openstack_password      = data.external.openstack_env.result["OS_PASSWORD"]
    openstack_domain_name   = data.external.openstack_env.result["OS_USER_DOMAIN_NAME"]
    openstack_project_id    = data.external.openstack_env.result["OS_PROJECT_ID"]
    openstack_region        = data.external.openstack_env.result["OS_REGION_NAME"]
    openstack_network_name  = var.subnet_name
    cluster_name            = var.cluster_name
  })
  filename = "${path.module}/../juju/config.yaml"
}

# Generate OpenStack overlay for Charmed Kubernetes
resource "local_file" "openstack_overlay" {
  content = templatefile("${path.module}/templates/openstack-overlay.yaml.tpl", {
    cluster_name = var.cluster_name
  })
  filename = "${path.module}/../juju/openstack-overlay.yaml"
}

# Read OpenStack environment variables
data "external" "openstack_env" {
  program = ["bash", "-c", "env | grep OS_ | sed 's/^/\"/;s/=/\":\"/;s/$/\",/' | tr -d '\\n' | sed 's/,$//' | echo '{' $(cat) '}'"]
}

resource "random_id" "token" {
  count       = 2
  byte_length = 32
}

# Generate BinderHub values
resource "local_file" "binderhub_values" {
  content = templatefile("${path.module}/templates/binderhub-values.yaml.tpl", {
    binderhub_domain    = var.binderhub_domain
    binderhub_subdomain = var.binderhub_subdomain
    registry_url        = var.registry_url
    registry_username   = var.registry_username
    registry_password   = var.registry_password
    binderhub_version   = var.binderhub_version
    cluster_name        = var.cluster_name
    api_token           = random_id.token[0].hex
    secret_token        = random_id.token[1].hex
  })
  filename = "${path.module}/../helm-charts/binderhub-values.yaml"
}

# Generate BinderHub issuer configuration
resource "local_file" "binderhub_issuer" {
  content = templatefile("${path.module}/templates/production-binderhub-issuer.yaml.tpl", {
    email_contact = var.email_contact
  })
  filename = "${path.module}/../helm-charts/production-binderhub-issuer.yaml"
}

# Generate Nginx Ingress configuration
resource "local_file" "nginx_ingress" {
  content = templatefile("${path.module}/templates/nginx-ingress.yaml.tpl", {})
  filename = "${path.module}/../helm-charts/nginx-ingress.yaml"
}

# Generate Prometheus and Grafana configuration
resource "local_file" "prometheus_values" {
  content = templatefile("${path.module}/templates/prometheus-values.yaml.tpl", {
    grafana_subdomain    = var.grafana_subdomain
    grafana_domain       = var.grafana_domain
    prometheus_subdomain = var.prometheus_subdomain
  })
  filename = "${path.module}/../helm-charts/prometheus-values.yaml"
}

resource "null_resource" "wait_for_cloud_init" {
  depends_on = [
    openstack_compute_instance_v2.master,
    openstack_compute_floatingip_associate_v2.master_fip_associate
  ]

  connection {
    type        = "ssh"
    user        = var.admin_user
    host        = openstack_networking_floatingip_v2.master_fip.address
    private_key = file("${var.ssh_private_key_path}/${var.ssh_key_name}")
    timeout     = "10m"
  }

  # Check if cloud-init has completed
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete on master node...'",
      "cloud-init status --wait >> /dev/null",
      "echo 'Cloud-init completed successfully'",
    ]
  }
}

resource "null_resource" "wait_for_worker_cloud_init" {
  count = var.worker_count
  
  depends_on = [
    openstack_compute_instance_v2.worker,
    null_resource.wait_for_cloud_init
  ]

  connection {
    type        = "ssh"
    user        = var.admin_user
    host        = openstack_compute_instance_v2.worker[count.index].network.0.fixed_ip_v4
    private_key = file("${var.ssh_private_key_path}/${var.ssh_key_name}")
    timeout     = "10m"
    bastion_host = openstack_networking_floatingip_v2.master_fip.address
    bastion_user = var.admin_user
  }

  # Check if cloud-init has completed
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete on worker node ${count.index}...'",
      "cloud-init status --wait >> /dev/null",
      "echo 'Cloud-init completed successfully on worker node ${count.index}'",
    ]
  }
}

resource "local_file" "juju_deploy_script" {
  content = templatefile("${path.module}/templates/juju-deploy.sh.tpl", {
    cluster_name       = var.cluster_name
    admin_user         = var.admin_user
    master_private_ip  = openstack_compute_instance_v2.master.network.0.fixed_ip_v4
    worker_private_ips = [for worker in openstack_compute_instance_v2.worker : worker.network.0.fixed_ip_v4]
  })
  filename = "${path.module}/../juju/deploy.sh"
  file_permission = "0755"
}


# Deploy Charmed Kubernetes
resource "null_resource" "deploy_charmed_kubernetes" {
  depends_on = [
    local_file.juju_config,
    local_file.juju_deploy_script,
    local_file.openstack_overlay,
    null_resource.wait_for_cloud_init,
    null_resource.wait_for_worker_cloud_init
  ]

  connection {
    type        = "ssh"
    user        = var.admin_user
    host        = openstack_networking_floatingip_v2.master_fip.address
    private_key = file("${var.ssh_private_key_path}/${var.ssh_key_name}")
    timeout     = "10m"
  }

  # Copy configuration files to master node
  provisioner "file" {
    source      = "${path.module}/../juju"
    destination = "/home/${var.admin_user}"
  }

  # Deploy Charmed Kubernetes using the script
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/${var.admin_user}/juju/deploy.sh",
      "/home/${var.admin_user}/juju/deploy.sh"
    ]
  }
}

# Fetch kubeconfig
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [
    null_resource.deploy_charmed_kubernetes
  ]

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/../.kube
      scp -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path}/${var.ssh_key_name} \
        ${var.admin_user}@${openstack_networking_floatingip_v2.master_fip.address}:/home/${var.admin_user}/.kube/config \
        ${path.module}/../.kube/config
    EOT
  }
}

# Create Cloudflare API token secret for cert-manager
resource "null_resource" "create_cloudflare_secret" {
  depends_on = [
    null_resource.fetch_kubeconfig
  ]

  provisioner "local-exec" {
    working_dir = "${path.module}/.."
    environment = {
      KUBECONFIG = "${path.module}/../.kube/config"
    }
    command = <<-EOT
      # Create namespace if it doesn't exist
      kubectl create namespace binderhub --dry-run=client -o yaml | kubectl apply -f -
      
      # Create Cloudflare API token secret
      kubectl create secret generic cloudflare-api-token-secret \
        --namespace binderhub \
        --from-literal=api-token=${var.cloudflare_token} \
        --dry-run=client -o yaml | kubectl apply -f -
      
      # Apply the cert-manager issuer
      kubectl apply -f helm-charts/production-binderhub-issuer.yaml
    EOT
  }
}

# Deploy BinderHub and monitoring stack
resource "null_resource" "deploy_applications" {
  depends_on = [
    null_resource.fetch_kubeconfig,
    local_file.binderhub_values,
    local_file.nginx_ingress,
    local_file.prometheus_values,
    null_resource.create_cloudflare_secret
  ]

  provisioner "local-exec" {
    working_dir = "${path.module}/.."
    environment = {
      KUBECONFIG = "${path.module}/../.kube/config"
    }
    command = <<-EOT
      # Add Helm repositories
      helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
      helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
      helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx/
      helm repo update

      # Create namespaces
      kubectl create namespace binderhub --dry-run=client -o yaml | kubectl apply -f -
      kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

      # Deploy Ingress Nginx
      helm install binderhub-proxy ingress-nginx/ingress-nginx \
        --namespace=binderhub \
        -f helm-charts/nginx-ingress.yaml \
        --version 4.1.4

      # Deploy BinderHub
      echo "Deploying BinderHub..."
      helm install binderhub jupyterhub/binderhub \
        --version=${var.binderhub_version} \
        --namespace binderhub \
        -f helm-charts/binderhub-values.yaml

      # Deploy Prometheus and Grafana
      echo "Deploying Prometheus and Grafana..."
      helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        -f helm-charts/prometheus-values.yaml
    EOT
  }
}

# Outputs
output "master_ip" {
  value = openstack_networking_floatingip_v2.master_fip.address
}

output "worker_private_ips" {
  value = [for worker in openstack_compute_instance_v2.worker : worker.network.0.fixed_ip_v4]
}

output "master_private_ip" {
  value = openstack_compute_instance_v2.master.network.0.fixed_ip_v4
}

output "binderhub_url" {
  value = "https://${var.binderhub_subdomain}.${var.binderhub_domain}"
}

output "grafana_url" {
  value = "https://${var.grafana_subdomain}.${var.grafana_domain}"
}

output "prometheus_url" {
  value = "https://${var.prometheus_subdomain}.${var.grafana_domain}"
}

output "kubeconfig_path" {
  value = "${path.module}/../.kube/config"
}