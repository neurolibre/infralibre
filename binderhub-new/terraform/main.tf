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

# Master node
resource "openstack_compute_instance_v2" "master" {
  name            = "${var.cluster_name}-master"
  image_name      = var.image_name
  flavor_name     = var.flavor_master
  key_pair        = openstack_compute_keypair_v2.keypair[0].name  # Using the first keypair for OpenStack
  security_groups = [openstack_networking_secgroup_v2.k8s_secgroup.name]

  # Add all SSH keys to the instance via cloud-init
  user_data = <<-EOF
    #cloud-config
    ssh_authorized_keys:
      ${join("\n      ", [for key in var.ssh_authorized_keys : key])}
  EOF

  network {
    port = openstack_networking_port_v2.master.id
  }

  metadata = {
    role = "master"
  }

  # Wait for cloud-init to complete
  provisioner "remote-exec" {
    inline = ["echo 'Waiting for cloud-init to complete...'", "cloud-init status --wait  > /dev/null"]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = openstack_networking_floatingip_v2.master_fip.address
    }
  }
}

# Worker node
resource "openstack_compute_instance_v2" "worker" {
  name            = "${var.cluster_name}-worker"
  image_name      = var.image_name
  flavor_name     = var.flavor_worker
  key_pair        = openstack_compute_keypair_v2.keypair[0].name  # Using the first keypair for OpenStack
  security_groups = [openstack_networking_secgroup_v2.k8s_secgroup.name]

  # Add all SSH keys to the instance via cloud-init
  user_data = <<-EOF
    #cloud-config
    ssh_authorized_keys:
      ${join("\n      ", [for key in var.ssh_authorized_keys : key])}
  EOF

  network {
    uuid = data.openstack_networking_network_v2.subnet.id
  }

  metadata = {
    role = "worker"
  }

  # Wait for cloud-init to complete
  provisioner "remote-exec" {
    inline = ["echo 'Waiting for cloud-init to complete...'", "cloud-init status --wait  > /dev/null"]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = openstack_compute_instance_v2.master.network.0.fixed_ip_v4
      bastion_host = openstack_networking_floatingip_v2.master_fip.address
      bastion_user = "ubuntu"
      bastion_private_key = file(var.ssh_private_key_path)
    }
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
    worker_ip          = openstack_compute_instance_v2.worker.network.0.fixed_ip_v4
    master_private_ip  = openstack_compute_instance_v2.master.network.0.fixed_ip_v4
    worker_private_ip  = openstack_compute_instance_v2.worker.network.0.fixed_ip_v4
  })
  filename = "${path.module}/../kubespray/inventory/binderhub/hosts.yaml"

  depends_on = [
    openstack_compute_floatingip_associate_v2.master_fip_associate,
    openstack_compute_instance_v2.worker
  ]
}

resource "local_file" "k8s_cluster_vars" {
  content = templatefile("${path.module}/templates/k8s-cluster.yml.tpl", {})
  filename = "${path.module}/../kubespray/inventory/binderhub/group_vars/k8s_cluster/k8s-cluster.yml"

  depends_on = [
    local_file.kubespray_inventory
  ]
}

# Generate BinderHub values
resource "local_file" "binderhub_values" {
  content = templatefile("${path.module}/templates/binderhub-values.yaml.tpl", {
    binderhub_domain   = var.binderhub_domain
    grafana_domain     = var.grafana_domain
    registry_url       = var.registry_url
    registry_username  = var.registry_username
    registry_password  = var.registry_password
    binderhub_version  = var.binderhub_version
  })
  filename = "${path.module}/../helm-charts/binderhub-values.yaml"
}

# Deploy Kubernetes with Kubespray
resource "null_resource" "deploy_kubernetes" {
  depends_on = [
    local_file.kubespray_inventory,
    local_file.k8s_cluster_vars,
    openstack_compute_instance_v2.master,
    openstack_compute_instance_v2.worker,
    openstack_compute_floatingip_associate_v2.master_fip_associate
  ]

  provisioner "local-exec" {
    working_dir = "${path.module}/.."
    command = <<-EOT
      # Clone Kubespray if not already present
      if [ ! -d "kubespray/kubespray" ]; then
        mkdir -p kubespray
        git clone https://github.com/kubernetes-sigs/kubespray.git kubespray/kubespray
        cd kubespray/kubespray
        git checkout v2.23.1
        pip install -r requirements.txt
        cd ../..
      fi

      # Run Kubespray
      cd kubespray
      ansible-playbook -i inventory/binderhub/hosts.yaml kubespray/cluster.yml -b -v \
        --private-key=${var.ssh_private_key_path} \
        -e ansible_user=ubuntu
    EOT
  }

  # Fetch kubeconfig
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/../.kube
      scp -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} \
        ubuntu@${openstack_networking_floatingip_v2.master_fip.address}:/etc/kubernetes/admin.conf \
        ${path.module}/../.kube/config
    EOT
  }
}

# Deploy BinderHub and monitoring stack
resource "null_resource" "deploy_applications" {
  depends_on = [
    null_resource.deploy_kubernetes,
    local_file.binderhub_values
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
      helm repo update

      # Create namespaces
      kubectl create namespace binderhub --dry-run=client -o yaml | kubectl apply -f -
      kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

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
        --set grafana.adminPassword=admin \
        --set prometheus.service.type=ClusterIP \
        --set grafana.service.type=ClusterIP \
        --set grafana.ingress.enabled=true \
        --set grafana.ingress.annotations."kubernetes\.io/ingress\.class"=nginx \
        --set grafana.ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
        --set grafana.ingress.hosts[0]=${var.grafana_subdomain}.${cloudflare_record.domain[0].zone} \
        --set grafana.ingress.tls[0].secretName=grafana-tls \
        --set grafana.ingress.tls[0].hosts[0]=${var.grafana_subdomain}.${cloudflare_record.domain[0].zone} \
        --set prometheus.ingress.enabled=true \
        --set prometheus.ingress.annotations."kubernetes\.io/ingress\.class"=nginx \
        --set prometheus.ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
        --set prometheus.ingress.hosts[0]=${var.prometheus_subdomain}.${cloudflare_record.domain[0].zone} \
        --set prometheus.ingress.tls[0].secretName=prometheus-tls \
        --set prometheus.ingress.tls[0].hosts[0]=${var.prometheus_subdomain}.${cloudflare_record.domain[0].zone}
    EOT
  }
}

# Outputs
output "master_ip" {
  value = openstack_networking_floatingip_v2.master_fip.address
}

output "worker_private_ip" {
  value = openstack_compute_instance_v2.worker.network.0.fixed_ip_v4
}

output "master_private_ip" {
  value = openstack_compute_instance_v2.master.network.0.fixed_ip_v4
}

output "binderhub_url" {
  value = "https://${var.binderhub_subdomain}.${cloudflare_record.domain[0].zone}"
}

output "grafana_url" {
  value = "https://${var.grafana_subdomain}.${cloudflare_record.domain[0].zone}"
}

output "prometheus_url" {
  value = "https://${var.prometheus_subdomain}.${cloudflare_record.domain[0].zone}"
}

output "kubeconfig_path" {
  value = "${path.module}/../.kube/config"
} 