resource "local_file" "install_binderhub_and_monitoring" {
    content = templatefile("${path.module}/../../templates/bash/install-binderhub-and-monitoring.sh.tpl", {
    cloudflare_api_token  = var.cloudflare_api_token
    binderhub_version = var.binderhub_version
    cluster_name      = var.cluster_name
    admin_user        = var.admin_user
    worker_count      = var.worker_count
    is_load_balancer  = var.is_load_balancer
    is_calico_rr      = var.is_calico_rr
    })
    filename = "${path.module}/../../../scripts/install-binderhub-and-monitoring.sh"
    file_permission = "0755"   
}

resource "local_file" "allow_pod_pockets" {
    content = templatefile("${path.module}/../../templates/bash/allow-pod-packets.sh.tpl", {
    kube_service_addresses = var.kube_service_addresses
    kube_pods_subnet       = var.kube_pods_subnet
    security_group_id      = var.security_group_id
    load_balancer_ip       = var.load_balancer_ip
    is_load_balancer       = var.is_load_balancer
    })
    filename = "${path.module}/../../../scripts/allow-pod-packets.sh" 
    file_permission = "0755"   
}

resource "local_file" "deploy_kubernetes" {
    content = templatefile("${path.module}/../../templates/bash/deploy-kubernetes.sh.tpl", {
    ssh_private_key_path = var.ssh_private_key_path
    admin_user           = var.admin_user
    kubespray_version_branch = var.kubespray_version_branch
    })
    filename        = "${path.module}/../../../scripts/deploy-kubernetes.sh"
    file_permission = "0755"                                                 
}

resource "local_file" "configure_kubectl" {
  # Use templatefile instead of local variable content
  content = templatefile("${path.module}/../../templates/bash/configure-kubectl.sh.tpl", {
    admin_user = var.admin_user
  })
  filename        = "${path.module}/../../../scripts/configure-kubectl.sh"
  file_permission = "0755" # Added file permission for consistency
}
