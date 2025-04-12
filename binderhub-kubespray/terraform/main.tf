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
  template = file("${path.module}/templates/cloud-init-cluster.yml.tpl")
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
  content = templatefile("${path.module}/templates/inventory.ini.tpl", {
    cluster_name       = var.cluster_name
    master_ip          = openstack_networking_floatingip_v2.master_fip.address
    master_private_ip  = openstack_compute_instance_v2.master.network.0.fixed_ip_v4
    worker_private_ips = [for worker in openstack_compute_instance_v2.worker : worker.network.0.fixed_ip_v4]
    admin_user = var.admin_user
  })
  filename = "${path.module}/../kubespray/inventory/binderhub/inventory.ini"

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
    load_balancer_ip = openstack_networking_floatingip_v2.master_fip.address
  })
  filename = "${path.module}/../kubespray/inventory/binderhub/group_vars/k8s_cluster/k8s-cluster.yml"

  depends_on = [
    local_file.kubespray_inventory
  ]
}

resource "local_file" "openstack_vars" {
  content = templatefile("${path.module}/templates/openstack.yml.tpl", {
    openstack_username           = data.external.openstack_env.result["OS_USERNAME"]
    openstack_password           = data.external.openstack_env.result["OS_PASSWORD"]
    openstack_project_id         = data.external.openstack_env.result["OS_PROJECT_ID"]
    openstack_auth_url           = data.external.openstack_env.result["OS_AUTH_URL"]
    openstack_region             = data.external.openstack_env.result["OS_REGION_NAME"]
    openstack_project_name       = data.external.openstack_env.result["OS_PROJECT_NAME"]
    openstack_domain_name        = data.external.openstack_env.result["OS_USER_DOMAIN_NAME"]
    openstack_subnet_id          = data.openstack_networking_network_v2.subnet.id
    openstack_external_network_id = data.openstack_networking_network_v2.network.id
    cinder_zone                  = var.cinder_zone
  })
  filename = "${path.module}/../kubespray/inventory/binderhub/group_vars/k8s_cluster/openstack.yml"

  depends_on = [
    local_file.kubespray_inventory
  ]
}

resource "random_id" "token" {
  count       = 2
  byte_length = 32
}

data "openstack_images_image_v2" "ubuntu" {
  name        = var.image_name
}

# https://jupyterhub.readthedocs.io/en/latest/explanation/database.html
# Cinder volume to be bound by the JupyterHub pod
resource "openstack_blockstorage_volume_v3" "hub_db_volume" {
  name        = "${var.cluster_name}-hub-db"
  size        = 1
  description = "Cinder volume to be bound by the JupyterHub pod"
  availability_zone = var.cinder_zone
}

resource "local_file" "cinder_pv" {
  depends_on = [
    openstack_blockstorage_volume_v3.hub_db_volume
  ]

  content = templatefile("${path.module}/templates/deploy/pv-cinder.yaml.tpl", {
    cinder_zone = var.cinder_zone
    cinder_db_volume_id = openstack_blockstorage_volume_v3.hub_db_volume.id
  })
  filename = "${path.module}/../helm-charts/pv-cinder.yaml"
}

# Generate BinderHub values
resource "local_file" "binderhub_values" {
  content = templatefile("${path.module}/templates/deploy/binderhub-values.yaml.tpl", {
    binderhub_domain   = var.binderhub_domain
    binderhub_subdomain = var.binderhub_subdomain
    registry_url       = var.registry_url
    registry_username  = var.registry_username
    registry_password  = var.registry_password
    binderhub_version  = var.binderhub_version
    cluster_name       = var.cluster_name
    cinder_zone        = var.cinder_zone
    api_token       = random_id.token[0].hex
    secret_token    = random_id.token[1].hex
    load_balancer_ip = openstack_networking_floatingip_v2.master_fip.address
  })
  filename = "${path.module}/../helm-charts/binderhub-values.yaml"
}

# Generate BinderHub issuer configuration
resource "local_file" "binderhub_issuer" {
  content = templatefile("${path.module}/templates/deploy/production-binderhub-issuer.yaml.tpl", {
    email_contact = var.email_contact
  })
  filename = "${path.module}/../helm-charts/production-binderhub-issuer.yaml"
}

# Generate Nginx Ingress configuration
resource "local_file" "nginx_ingress" {
  content = templatefile("${path.module}/templates/deploy/nginx-ingress.yaml.tpl", {})
  filename = "${path.module}/../helm-charts/nginx-ingress.yaml"
}

# Generate Prometheus and Grafana configuration
resource "local_file" "prometheus_values" {
  content = templatefile("${path.module}/templates/deploy/prometheus-values.yaml.tpl", {
    grafana_subdomain = var.grafana_subdomain
    grafana_domain = var.grafana_domain
    prometheus_subdomain = var.prometheus_subdomain
  })
  filename = "${path.module}/../helm-charts/prometheus-values.yaml"
}

resource "local_file" "install_binderhub_and_monitoring" {
  content = templatefile("${path.module}/templates/deploy/install-binderhub-and-monitoring.sh.tpl", {
    cloudflare_token = var.cloudflare_token
    binderhub_version = var.binderhub_version
    cluster_name = var.cluster_name
    admin_user = var.admin_user
  })
  filename = "${path.module}/../scripts/install-binderhub-and-monitoring.sh"
}

resource "terraform_data" "wait_for_cloud_init" {
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

resource "terraform_data" "wait_for_worker_cloud_init" {
  count = var.worker_count
  
  depends_on = [
    openstack_compute_instance_v2.worker,
    terraform_data.wait_for_cloud_init
  ]

  connection {
    type        = "ssh"
    user        = var.admin_user
    host        = openstack_compute_instance_v2.worker[count.index].network.0.fixed_ip_v4
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

resource "local_file" "all_vars" {
  content = templatefile("${path.module}/templates/all.yml.tpl", {})
  filename = "${path.module}/../kubespray/inventory/binderhub/group_vars/all/all.yml"

  depends_on = [
    local_file.kubespray_inventory
  ]
}


# Ensure SSH keys are properly set up
resource "terraform_data" "prepare_ssh_environment" {
  depends_on = [
    terraform_data.wait_for_cloud_init,
    terraform_data.wait_for_worker_cloud_init
  ]

  provisioner "local-exec" {
    command = <<-EOT
      # Add master to known hosts
      ssh-keyscan -H ${openstack_networking_floatingip_v2.master_fip.address} >> ~/.ssh/known_hosts
      
      # Test SSH to master
      ssh -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path}/${var.ssh_key_name} ${var.admin_user}@${openstack_networking_floatingip_v2.master_fip.address} echo "SSH to master successful"
      
      # Test SSH to workers through bastion (master)
      for ip in ${join(" ", [for worker in openstack_compute_instance_v2.worker : worker.network.0.fixed_ip_v4])}; do
        echo "Testing SSH to worker $ip through master..."
        ssh -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path}/${var.ssh_key_name} -o ProxyCommand="ssh -i ${var.ssh_private_key_path}/${var.ssh_key_name} -W %h:%p ${var.admin_user}@${openstack_networking_floatingip_v2.master_fip.address}" ${var.admin_user}@$ip echo "SSH to worker $ip successful"
      done
    EOT
  }
}

# Deploy Kubernetes with Kubespray
resource "terraform_data" "deploy_kubernetes" {
  depends_on = [
    local_file.kubespray_inventory,
    local_file.k8s_cluster_vars,
    terraform_data.wait_for_cloud_init,
    terraform_data.wait_for_worker_cloud_init,
    terraform_data.prepare_ssh_environment
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

        echo "Copying inventory to cloned Kubespray"
        mkdir -p inventory/binderhub
        cp -r ../inventory/binderhub/* inventory/binderhub/
        echo "Inventory copied"

        cd ../..
      fi

      # Run Kubespray
      cd kubespray/kubespray
      ansible-playbook -i inventory/binderhub/inventory.ini cluster.yml -b -v \
        --private-key=${var.ssh_private_key_path}/${var.ssh_key_name} \
        -e ansible_user=ubuntu
      
      echo "Kubernetes deployment completed successfully!!"
    EOT
  }
  
}

resource "terraform_data" "configure_kubectl_copy_files" {
  depends_on = [
    terraform_data.deploy_kubernetes
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
      "echo 'Configuring kubectl...'",
      "mkdir -p $HOME/.kube",
      "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config",
      "echo 'kubectl configured successfully'",
      "mkdir -p $HOME/deploy",
    ]
  }
}

# Deploy BinderHub and monitoring stack
resource "terraform_data" "deploy_applications" {
  depends_on = [
    terraform_data.configure_kubectl_copy_files,
    local_file.cinder_pv,
    local_file.binderhub_values,
    local_file.binderhub_issuer,
    local_file.nginx_ingress,
    local_file.prometheus_values,
    local_file.install_binderhub_and_monitoring
  ]

  connection {
    type        = "ssh"
    user        = var.admin_user
    host        = openstack_networking_floatingip_v2.master_fip.address
    timeout     = "10m"
  }

  provisioner "file" {
    source = "${path.module}/../helm-charts/pv-cinder.yaml"
    destination = "/home/${var.admin_user}/deploy/pv-cinder.yaml"
  }

  provisioner "file" {
    source = "${path.module}/../helm-charts/production-binderhub-issuer.yaml"
    destination = "/home/${var.admin_user}/deploy/production-binderhub-issuer.yaml"
  }

  provisioner "file" {
    source = "${path.module}/../helm-charts/binderhub-values.yaml"
    destination = "/home/${var.admin_user}/deploy/binderhub-values.yaml"
  }

  provisioner "file" {
    source = "${path.module}/../scripts/install-binderhub-and-monitoring.sh"
    destination = "/home/${var.admin_user}/deploy/install-binderhub-and-monitoring.sh"
  }

  provisioner "file" {
    source = "${path.module}/../helm-charts/prometheus-values.yaml"
    destination = "/home/${var.admin_user}/deploy/prometheus-values.yaml"
  }

  provisioner "file" {
    source = "${path.module}/../helm-charts/nginx-ingress.yaml"
    destination = "/home/${var.admin_user}/deploy/nginx-ingress.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Deploying BinderHub and monitoring stack...'",
      "chmod +x /home/${var.admin_user}/deploy/install-binderhub-and-monitoring.sh",
      "bash /home/${var.admin_user}/deploy/install-binderhub-and-monitoring.sh",
      "echo 'BinderHub and monitoring stack deployed successfully'"
    ]
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