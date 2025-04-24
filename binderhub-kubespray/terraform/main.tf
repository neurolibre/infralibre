module "dns" {
  source = "./modules/dns"
  floating_ip = module.network.floating_ip

  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id = var.cloudflare_zone_id
  binderhub_subdomain = var.binderhub_subdomain
  jupyterhub_subdomain = var.jupyterhub_subdomain
  grafana_subdomain = var.grafana_subdomain
  prometheus_subdomain = var.prometheus_subdomain

}

module "network" {
  source = "./modules/network"
  public_network_name = var.public_network_name
  internal_network_name = var.internal_network_name
  internal_subnet_name = var.internal_subnet_name
  cluster_name = var.cluster_name
  kube_service_addresses = var.kube_service_addresses
  kube_pods_subnet = var.kube_pods_subnet
}

module "compute" {
  source = "./modules/compute"

  network_floating_ip = module.network.floating_ip
  network_master_port_id = module.network.master_port_id
  network_internal_id = module.network.internal_network_id
  network_security_group_ids = [module.network.k8s_sg_id]
  network_public_pool_name = module.network.public_network_name
  
  ceph_rule_name = var.ceph_rule_name
  ceph_rule_key = var.ceph_rule_key
  ceph_share_hash = var.ceph_share_hash
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

module "kubespray" {
  source = "./modules/kubespray"
  
  openstack_internal_network_id = module.network.internal_network_id
  openstack_public_network_id = module.network.public_network_id
  master_floating_ip = module.network.floating_ip
  master_private_ip = module.compute.master_private_ip  
  worker_private_ips = module.compute.worker_private_ips

  is_calico_rr = var.is_calico_rr
  cluster_name = var.cluster_name
  admin_user = var.admin_user
  kube_service_addresses = var.kube_service_addresses
  kube_pods_subnet = var.kube_pods_subnet
  k8s_version = var.k8s_version
  is_load_balancer = var.is_load_balancer
}

module "helm" {
  source = "./modules/helm"

  load_balancer_ip = module.network.floating_ip
  master_private_ip = module.compute.master_private_ip
  cinder_db_volume_id = module.compute.hub_db_volume_id

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
  is_load_balancer = var.is_load_balancer
}

module "bash" {
  source = "./modules/bash"
  kubespray_version_branch = var.kubespray_version_branch
  cloudflare_api_token = var.cloudflare_api_token # TLS
  binderhub_version = var.binderhub_version
  cluster_name = var.cluster_name
  admin_user = var.admin_user
  worker_count = var.worker_count
  kube_service_addresses = var.kube_service_addresses
  kube_pods_subnet = var.kube_pods_subnet
  security_group_id = module.network.k8s_sg_id
  load_balancer_ip = module.network.floating_ip
  ssh_private_key_path = var.ssh_private_key_path
  is_load_balancer = var.is_load_balancer
  is_calico_rr = var.is_calico_rr
}

# Deploy Kubernetes with Kubespray
resource "terraform_data" "deploy_kubernetes" {
  depends_on = [
    module.kubespray,
    module.bash,
    module.compute
  ]

  provisioner "local-exec" {
    working_dir = "${path.module}/.."
    command = "bash scripts/deploy-kubernetes.sh"
  }
  
}

resource "terraform_data" "configure_kubectl" {
  depends_on = [
    terraform_data.deploy_kubernetes
  ]

  connection {
    type        = "ssh"
    user        = var.admin_user
    host        = module.network.floating_ip
    timeout     = "10m"
  }

  provisioner "file" {
    source = "${path.module}/../scripts/configure-kubectl.sh"
    destination = "/home/${var.admin_user}/configure-kubectl.sh"
  }

  # Check if cloud-init has completed
  provisioner "remote-exec" {
    inline = [
      "echo '============ 🧊 Configuring kubectl'",
      "bash /home/${var.admin_user}/configure-kubectl.sh",
      "mkdir -p /home/${var.admin_user}/deploy",
      "echo '============ 🎉 Created deploy directory'"
    ]
  }
}

resource "null_resource" "configure_docker_credentials" {
  count = length(concat([module.compute.master_private_ip], module.compute.worker_private_ips))

  connection {
    type        = "ssh"
    user        = var.admin_user
    private_key = file(var.ssh_private_key_path)
    host        = concat([module.compute.master_private_ip], module.compute.worker_private_ips)[count.index]
    timeout     = "10m"
    bastion_host = module.network.floating_ip
    bastion_user = var.admin_user
  }

  provisioner "remote-exec" {
    inline = [
      "echo '🐳 Configuring docker credentials for ${concat([module.compute.master_private_ip], module.compute.worker_private_ips)[count.index]}...'",
      "mkdir -p /home/${var.admin_user}/.docker",
      "sudo docker login ${var.registry_url} --username ${var.registry_username} --password ${var.registry_password}"
    ]
  }
}

# Deploy BinderHub and monitoring stack
resource "terraform_data" "deploy_applications" {
  depends_on = [
    terraform_data.configure_kubectl,
    module.helm,
    module.bash
  ]

  connection {
    type        = "ssh"
    user        = var.admin_user
    host        = module.network.floating_ip
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
    source = "${path.module}/../helm-charts/metallb-l2.yaml"
    destination = "/home/${var.admin_user}/deploy/metallb-l2.yaml"
  }
  provisioner "file" {
    source = "${path.module}/../helm-charts/binderhub-values.yaml"
    destination = "/home/${var.admin_user}/deploy/binderhub-values.yaml"
  }
  provisioner "file" {
    source = "${path.module}/../helm-charts/prometheus-values.yaml"
    destination = "/home/${var.admin_user}/deploy/prometheus-values.yaml"
  }
  provisioner "file" {
    source = "${path.module}/../helm-charts/nginx-ingress.yaml"
    destination = "/home/${var.admin_user}/deploy/nginx-ingress.yaml"
  }

  provisioner "file" {
    source = "${path.module}/../scripts/install-binderhub-and-monitoring.sh"
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