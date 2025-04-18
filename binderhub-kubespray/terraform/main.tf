module "dns" {
  source = "./modules/dns"
  cloudflare_token = var.cloudflare_token
  cloudflare_zone_id = var.cloudflare_zone_id
  binderhub_subdomain = var.binderhub_subdomain
  jupyterhub_subdomain = var.jupyterhub_subdomain
  grafana_subdomain = var.grafana_subdomain
  prometheus_subdomain = var.prometheus_subdomain
  ip = module.openstack_network.floating_ip

  depends_on = [
    module.openstack_network
  ]
}

module "openstack_network" {
  source = "./modules/openstack_network"
  public_network_name = var.network_name
  internal_network_name = var.subnet_name
  cluster_name = var.cluster_name
}

module "openstack_compute" {
  source = "./modules/openstack_compute"
  cluster_name = var.cluster_name
  
  image_name = var.image_name
  
  flavor_master = var.flavor_master
  flavor_worker = var.flavor_worker
  
  worker_count = var.worker_count
  network_floating_ip = module.openstack_network.floating_ip
  network_master_port_id = module.openstack_network.master_port_id
  network_internal_id = module.openstack_network.internal_network_id
  network_security_group_ids = [module.openstack_network.k8s_sg_id]
  network_public_pool_name = module.openstack_network.public_network_name
  
  ssh_authorized_keys = var.ssh_authorized_keys
  ssh_private_key_path = var.ssh_private_key_path
  
  cinder_availability_zone = var.db_cinder_zone
  cinder_volume_size = 1
  
  admin_user = var.admin_user
}

module "kubespray_config" {
  source = "./modules/kubespray_config"
  cluster_name = var.cluster_name
  master_floating_ip = module.openstack_network.floating_ip
  master_private_ip = module.openstack_compute.master_private_ip  
  worker_private_ips = module.openstack_compute.worker_private_ips
  admin_user = var.admin_user
  kube_service_addresses = var.kube_service_addresses
  kube_pods_subnet = var.kube_pods_subnet
  openstack_internal_network_id = module.openstack_network.internal_network_id
  openstack_public_network_id = module.openstack_network.public_network_id
}


resource "random_id" "token" {
  count       = 2
  byte_length = 32
}

resource "local_file" "metallb_ipaddresspool" {
  content = templatefile("${path.module}/templates/deploy/metallb_ipaddresspool.yaml.tpl", {
    load_balancer_ip = module.openstack_network.floating_ip
  })
  filename = "${path.module}/../helm-charts/metallb_ipaddresspool.yaml"
}

resource "local_file" "metallb_l2advertisement" {
  content = templatefile("${path.module}/templates/deploy/metallb_l2advertisement.yaml.tpl", {})
  filename = "${path.module}/../helm-charts/metallb_l2advertisement.yaml"
}

resource "local_file" "metallb_bgp" {
  content = templatefile("${path.module}/templates/deploy/metallb-bgp.yaml.tpl", {
    load_balancer_ip = module.openstack_network.floating_ip
    bgp_peer_address = module.openstack_compute.master_private_ip
  })
  filename = "${path.module}/../helm-charts/metallb-bgp.yaml"
} 

resource "local_file" "secrets" {
  content = templatefile("${path.module}/templates/deploy/secrets.yaml.tpl", {
    api_token = random_id.token[0].hex
    secret_token = random_id.token[1].hex
    registry_url = var.registry_url
    registry_username = var.registry_username
    registry_password = var.registry_password
  })
  filename = "${path.module}/../helm-charts/secrets.yaml"
}

resource "local_file" "cinder_pv" {
  depends_on = [
    module.openstack_compute
  ]

  content = templatefile("${path.module}/templates/deploy/pv-cinder.yaml.tpl", {
    cinder_db_volume_id = module.openstack_compute.hub_db_volume_id
  })
  filename = "${path.module}/../helm-charts/pv-cinder.yaml"
}

# Generate BinderHub values
resource "local_file" "binderhub_values" {
  content = templatefile("${path.module}/templates/deploy/binderhub-values.yaml.tpl", {
    binderhub_domain   = var.binderhub_domain
    binderhub_subdomain = var.binderhub_subdomain
    jupyterhub_subdomain = var.jupyterhub_subdomain
    binderhub_version  = var.binderhub_version
    cluster_name       = var.cluster_name
    load_balancer_ip = module.openstack_network.floating_ip
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
  content = templatefile("${path.module}/templates/deploy/nginx-ingress.yaml.tpl", {
    load_balancer_ip = module.openstack_network.floating_ip
  })
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
    worker_count = var.worker_count
  })
  filename = "${path.module}/../scripts/install-binderhub-and-monitoring.sh"
}

resource "local_file" "allow_pod_pockets" {
  depends_on = [
    module.openstack_network
  ]
  content = templatefile("${path.module}/templates/allow-pod-pockets.sh.tpl", {
    kube_service_addresses = var.kube_service_addresses
    kube_pods_subnet = var.kube_pods_subnet
    security_group_id = module.openstack_network.k8s_sg_id
    load_balancer_ip = module.openstack_network.floating_ip
  })
  filename = "${path.module}/../scripts/allow-pod-pockets.sh"
}

resource "local_file" "all_vars" {
  content = templatefile("${path.module}/templates/all.yml.tpl", {})
  filename = "${path.module}/../kubespray/inventory/binderhub/group_vars/all/all.yml"

  depends_on = [
    local_file.kubespray_inventory
  ]
}


# Deploy Kubernetes with Kubespray
resource "terraform_data" "deploy_kubernetes" {
  depends_on = [
    module.kubespray_config,
    local_file.allow_pod_pockets,
    module.openstack_compute
  ]

  provisioner "local-exec" {
    working_dir = "${path.module}/.."
    command = <<-EOT
      # ALLOW POD POCKETS =================================
      echo "Allowing pod pockets on all ports within this K8s cluster"
      chmod +x scripts/allow-pod-pockets.sh
      bash scripts/allow-pod-pockets.sh

      # CLONE KUBESPRAY =================================
      # - Install requirements (to local python)
      # - Install openstackclient (assumes credentials are loaded in local env)
      # - Openstackclient is used to allow pod pockets on all ports within this K8s cluster
      #   - Only relevant if metallb is enabled, quite troublesome on openstack.

      if [ ! -d "kubespray/kubespray" ]; then
        mkdir -p kubespray
        git clone https://github.com/kubernetes-sigs/kubespray.git kubespray/kubespray
        cd kubespray/kubespray
        git checkout release-2.27
        pip install -r requirements.txt
        pip install python-openstackclient

        # COPY INVENTORY ================================= IMPORTANT
        # - Depends on module.kubespray_config
        echo "Copying inventory to cloned Kubespray"
        mkdir -p inventory/binderhub
        cp -r ../inventory/binderhub/* inventory/binderhub/
        echo "Inventory copied"

        cd ../..
      fi

      # RUN KUBESPRAY =================================
      cd kubespray/kubespray
      ansible-playbook -i inventory/binderhub/inventory.ini cluster.yml -b -v \
        --private-key=${var.ssh_private_key_path} \
        -e ansible_user=ubuntu | tee ../../ansible-logfile.log
      
      echo "DONE with Kubespray"
    EOT
  }
  
}

resource "terraform_data" "configure_kubectl" {
  depends_on = [
    terraform_data.deploy_kubernetes
  ]

  connection {
    type        = "ssh"
    user        = var.admin_user
    host        = module.openstack_network.floating_ip
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
    terraform_data.configure_kubectl,
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
    host        = module.openstack_network.floating_ip
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
    source = "${path.module}/../helm-charts/secrets.yaml"
    destination = "/home/${var.admin_user}/deploy/secrets.yaml"
  }

  provisioner "file" {
    source = "${path.module}/../helm-charts/metallb-bgp.yaml"
    destination = "/home/${var.admin_user}/deploy/metallb-bgp.yaml"
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
    source = "${path.module}/../helm-charts/metallb_ipaddresspool.yaml"
    destination = "/home/${var.admin_user}/deploy/metallb_ipaddresspool.yaml"
  }
  
  provisioner "file" {
    source = "${path.module}/../helm-charts/metallb_l2advertisement.yaml"
    destination = "/home/${var.admin_user}/deploy/metallb_l2advertisement.yaml"
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