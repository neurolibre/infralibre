provider "cloudflare" {
  api_token = var.cloudflare_token
}

# Cloudflare DNS records
resource "cloudflare_record" "domain" {
  count   = length([var.binderhub_subdomain, var.grafana_subdomain, var.prometheus_subdomain])
  zone_id = var.cloudflare_zone_id
  name    = [var.binderhub_subdomain, var.grafana_subdomain, var.prometheus_subdomain][count.index]
  content   = openstack_networking_floatingip_v2.master_fip.address
  type    = "A"
  proxied = true
}


# Get details of an existing PUBLIC network
data "openstack_networking_network_v2" "network" {
  name           = var.network_name
  external       = true
}

# Get details of an existing INTERNAL network
# (that has its subnet) which is connected to the 
# Public-Network via a router.
data "openstack_networking_network_v2" "subnet" {
  name = var.subnet_name
}

# Create a keypair for each SSH key provided
resource "openstack_compute_keypair_v2" "keypair" {
  count      = length(var.ssh_authorized_keys)
  name       = "${var.cluster_name}-keypair-ed25519-${count.index}"
  public_key = var.ssh_authorized_keys[count.index]
}


# Create a PORT under the internal network which will be attached to 
# the master node with the security groups defined here.
resource "openstack_networking_port_v2" "master" {
  name               = "${var.cluster_name}-master"
  admin_state_up     = "true"
  network_id         = data.openstack_networking_network_v2.subnet.id
  security_group_ids = [
    openstack_networking_secgroup_v2.k8s_secgroup.id
    ]
}

data "template_file" "cloud_init_cluster" {
  template = file("${path.module}/templates/cloud-init-cluster.yaml.tpl")
  vars = {
    ssh_authorized_keys = indent(2, join("\n", formatlist("- %s", var.ssh_authorized_keys)))
  }
}

data "template_cloudinit_config" "cluster_config" {
  part {
    filename     = "cluster.yaml"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init_cluster.rendered
  }
}

# Master node
resource "openstack_compute_instance_v2" "master" {
  name            = "${var.cluster_name}-master"
  image_name      = var.image_name
  flavor_name     = var.flavor_master
  key_pair        = openstack_compute_keypair_v2.keypair[0].name  # Using the first keypair for OpenStack
  security_groups = [openstack_networking_secgroup_v2.k8s_secgroup.name]

  # Add all SSH keys to the instance via cloud-init
  user_data = data.template_cloudinit_config.cluster_config.rendered

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

  # Add all SSH keys to the instance via cloud-init
  user_data = data.template_cloudinit_config.cluster_config.rendered

  network {
    uuid = data.openstack_networking_network_v2.subnet.id
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


# Generate Kubespray inventory
resource "local_file" "kubespray_inventory" {
  content = templatefile("${path.module}/templates/hosts.yaml.tpl", {
    master_ip          = openstack_networking_floatingip_v2.master_fip.address
    master_private_ip  = openstack_compute_instance_v2.master.network.0.fixed_ip_v4
    worker_private_ips = [for worker in openstack_compute_instance_v2.worker : worker.network.0.fixed_ip_v4]
  })
  filename = "${path.module}/../kubespray/inventory/hosts.yaml"

  depends_on = [
    openstack_compute_floatingip_associate_v2.master_fip_associate,
    openstack_compute_instance_v2.worker
  ]
}

# Read OpenStack environment variables
data "external" "openstack_env" {
  program = ["bash", "-c", "env | grep OS_ | sed 's/^/\"/;s/=/\":\"/;s/$/\",/' | tr -d '\\n' | sed 's/,$//' | echo '{' $(cat) '}'"]
}

resource "local_file" "k8s_cluster_vars" {
  content = templatefile("${path.module}/templates/k8s-cluster.yml.tpl", {
    openstack_auth_url           = data.external.openstack_env.result["OS_AUTH_URL"]
    openstack_username           = data.external.openstack_env.result["OS_USERNAME"]
    openstack_password           = data.external.openstack_env.result["OS_PASSWORD"]
    openstack_domain_name        = data.external.openstack_env.result["OS_USER_DOMAIN_NAME"]
    openstack_project_id         = data.external.openstack_env.result["OS_PROJECT_ID"]
    openstack_region             = data.external.openstack_env.result["OS_REGION_NAME"]
    openstack_subnet_id          = data.openstack_networking_network_v2.subnet.id
    openstack_external_network_id = data.openstack_networking_network_v2.network.id
  })
  filename = "${path.module}/../kubespray/inventory/group_vars/k8s_cluster/k8s-cluster.yml"

  depends_on = [
    local_file.kubespray_inventory
  ]
}

resource "random_id" "token" {
  count       = 2
  byte_length = 32
}

# Generate BinderHub values
resource "local_file" "binderhub_values" {
  content = templatefile("${path.module}/templates/binderhub-values.yaml.tpl", {
    binderhub_domain   = var.binderhub_domain
    binderhub_subdomain = var.binderhub_subdomain
    registry_url       = var.registry_url
    registry_username  = var.registry_username
    registry_password  = var.registry_password
    binderhub_version  = var.binderhub_version
    cluster_name       = var.cluster_name
    api_token       = random_id.token[0].hex
    secret_token    = random_id.token[1].hex
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
    grafana_subdomain = var.grafana_subdomain
    grafana_domain = var.grafana_domain
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

# Deploy Kubernetes with Kubespray
resource "null_resource" "deploy_kubernetes" {
  depends_on = [
    local_file.kubespray_inventory,
    local_file.k8s_cluster_vars,
    null_resource.wait_for_cloud_init
  ]

  provisioner "local-exec" {
    working_dir = "${path.module}/.."
    command = <<-EOT
      # Clone Kubespray if not already present
      if [ ! -d "kubespray/kubespray" ]; then
        mkdir -p kubespray
        git clone https://github.com/kubernetes-sigs/kubespray.git kubespray/kubespray
        cd kubespray/kubespray
        git checkout release-2.27
        pip install -r requirements.txt
        cd ../..
      fi

      # WARNING: Set the ANSIBLE_ROLES_PATH environment variable
      export ANSIBLE_ROLES_PATH="$(pwd)/kubespray/roles:$ANSIBLE_ROLES_PATH"

      # Run Kubespray
      cd kubespray
      ansible-playbook -i inventory/hosts.yaml kubespray/cluster.yml -b -v \
        --private-key=${var.ssh_private_key_path}/${var.ssh_key_name} \
        -e ansible_user=ubuntu
    EOT
  }

  # Fetch kubeconfig
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/../.kube
      scp -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path}/${var.ssh_key_name} \
        ubuntu@${openstack_networking_floatingip_v2.master_fip.address}:/etc/kubernetes/admin.conf \
        ${path.module}/../.kube/config
    EOT
  }
}

# Create Cloudflare API token secret for cert-manager
resource "null_resource" "create_cloudflare_secret" {
  depends_on = [
    null_resource.deploy_kubernetes
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
    null_resource.deploy_kubernetes,
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