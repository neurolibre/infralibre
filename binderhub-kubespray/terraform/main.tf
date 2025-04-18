module "dns" {
  source = "./modules/dns"
  floating_ip = module.openstack_network.floating_ip

  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id = var.cloudflare_zone_id
  binderhub_subdomain = var.binderhub_subdomain
  jupyterhub_subdomain = var.jupyterhub_subdomain
  grafana_subdomain = var.grafana_subdomain
  prometheus_subdomain = var.prometheus_subdomain

}

module "openstack_network" {
  source = "./modules/openstack_network"
  public_network_name = var.public_network_name
  internal_network_name = var.internal_network_name
  cluster_name = var.cluster_name
}

module "openstack_compute" {
  source = "./modules/openstack_compute"

  network_floating_ip = module.openstack_network.floating_ip
  network_master_port_id = module.openstack_network.master_port_id
  network_internal_id = module.openstack_network.internal_network_id
  network_security_group_ids = [module.openstack_network.k8s_sg_id]
  network_public_pool_name = module.openstack_network.public_network_name
  
  cluster_name = var.cluster_name
  image_name = var.image_name
  flavor_master = var.flavor_master
  flavor_worker = var.flavor_worker
  worker_count = var.worker_count
  ssh_authorized_keys = var.ssh_authorized_keys
  ssh_private_key_path = var.ssh_private_key_path
  cinder_availability_zone = var.db_cinder_zone
  admin_user = var.admin_user

  cinder_volume_size = 1
}

module "kubespray_config" {
  source = "./modules/kubespray_config"
  
  openstack_internal_network_id = module.openstack_network.internal_network_id
  openstack_public_network_id = module.openstack_network.public_network_id
  master_floating_ip = module.openstack_network.floating_ip
  master_private_ip = module.openstack_compute.master_private_ip  
  worker_private_ips = module.openstack_compute.worker_private_ips

  cluster_name = var.cluster_name
  admin_user = var.admin_user
  kube_service_addresses = var.kube_service_addresses
  kube_pods_subnet = var.kube_pods_subnet
}

module "helm_config" {
  source = "./modules/helm_config"

  load_balancer_ip = module.openstack_network.floating_ip
  master_private_ip = module.openstack_compute.master_private_ip
  cinder_db_volume_id = module.openstack_compute.hub_db_volume_id

  cluster_name = var.cluster_name
  registry_url = var.registry_url
  registry_username = var.registry_username
  registry_password = var.registry_password
  main_domain = var.main_domain
  binderhub_subdomain = var.binderhub_subdomain
  jupyterhub_subdomain = var.jupyterhub_subdomain
  binderhub_version = var.binderhub_version
  grafana_subdomain = var.grafana_subdomain
  prometheus_subdomain = var.prometheus_subdomain
  email_contact = var.email_contact
}

module "scripts_template" {
  source = "./modules/scripts_template"

  cloudflare_api_token = var.cloudflare_api_token # TLS
  binderhub_version = var.binderhub_version
  cluster_name = var.cluster_name
  admin_user = var.admin_user
  worker_count = var.worker_count
  kube_service_addresses = var.kube_service_addresses
  kube_pods_subnet = var.kube_pods_subnet
  security_group_id = module.openstack_network.k8s_sg_id
  load_balancer_ip = module.openstack_network.floating_ip
  ssh_private_key_path = var.ssh_private_key_path
}

# Deploy Kubernetes with Kubespray
resource "terraform_data" "deploy_kubernetes" {
  depends_on = [
    module.kubespray_config,
    module.scripts_template,
    module.openstack_compute
  ]

  provisioner "local-exec" {
    working_dir = "${path.module}/.."
    command = module.scripts_template.deploy_kubernetes_script_filename
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

  provisioner "file" {
    source = module.scripts_template.configure_kubectl_script_filename
    destination = "/home/${var.admin_user}/deploy/configure-kubectl.sh"
  }

  # Check if cloud-init has completed
  provisioner "remote-exec" {
    inline = [
      "bash /home/${var.admin_user}/deploy/configure-kubectl.sh"
    ]
  }
}

# Deploy BinderHub and monitoring stack
resource "terraform_data" "deploy_applications" {
  depends_on = [
    terraform_data.configure_kubectl,
    module.helm_config,
    module.scripts_template
  ]

  connection {
    type        = "ssh"
    user        = var.admin_user
    host        = module.openstack_network.floating_ip
    timeout     = "10m"
  }

  provisioner "file" {
    source = module.helm_config.cinder_pv_file_path
    destination = "/home/${var.admin_user}/deploy/pv-cinder.yaml"
  }
  provisioner "file" {
    source = module.helm_config.binderhub_issuer_file_path
    destination = "/home/${var.admin_user}/deploy/production-binderhub-issuer.yaml"
  }
  provisioner "file" {
    source = module.helm_config.secrets_file_path
    destination = "/home/${var.admin_user}/deploy/secrets.yaml"
  }
  provisioner "file" {
    source = module.helm_config.metallb_bgp_file_path
    destination = "/home/${var.admin_user}/deploy/metallb-bgp.yaml"
  }
  provisioner "file" {
    source = module.helm_config.binderhub_values_file_path
    destination = "/home/${var.admin_user}/deploy/binderhub-values.yaml"
  }
  provisioner "file" {
    source = module.helm_config.prometheus_values_file_path
    destination = "/home/${var.admin_user}/deploy/prometheus-values.yaml"
  }
  provisioner "file" {
    source = module.helm_config.metallb_ipaddresspool_file_path
    destination = "/home/${var.admin_user}/deploy/metallb_ipaddresspool.yaml"
  }
  provisioner "file" {
    source = module.helm_config.metallb_l2advertisement_file_path
    destination = "/home/${var.admin_user}/deploy/metallb_l2advertisement.yaml"
  }
  provisioner "file" {
    source = module.helm_config.nginx_ingress_file_path
    destination = "/home/${var.admin_user}/deploy/nginx-ingress.yaml"
  }

  provisioner "file" {
    source = module.scripts_template.install_script_path
    destination = "/home/${var.admin_user}/deploy/install-binderhub-and-monitoring.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '============ 🚀 Deploying BinderHub and monitoring stack...'",
      "chmod +x /home/${var.admin_user}/deploy/install-binderhub-and-monitoring.sh",
      "bash /home/${var.admin_user}/deploy/install-binderhub-and-monitoring.sh",
      "echo '============= 🎉 END 🎉 ============='"
    ]
  }
}