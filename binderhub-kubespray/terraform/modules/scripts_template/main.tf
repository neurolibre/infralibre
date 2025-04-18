resource "local_file" "install_binderhub_and_monitoring" {
    content = templatefile("${path.module}/../../templates/deploy/install-binderhub-and-monitoring.sh.tpl", {
    cloudflare_token  = var.cloudflare_token
    binderhub_version = var.binderhub_version
    cluster_name      = var.cluster_name
    admin_user        = var.admin_user
    worker_count      = var.worker_count
    })
    filename = "${path.module}/../../../scripts/install-binderhub-and-monitoring.sh"
    file_permission = "0755"   
}

resource "local_file" "allow_pod_pockets" {
    content = templatefile("${path.module}/../../templates/allow-pod-pockets.sh.tpl", {
    kube_service_addresses = var.kube_service_addresses
    kube_pods_subnet       = var.kube_pods_subnet
    security_group_id      = var.security_group_id
    load_balancer_ip       = var.load_balancer_ip
    })
    filename = "${path.module}/../../../scripts/allow-pod-pockets.sh" 
    file_permission = "0755"   
}

resource "local_file" "deploy_kubernetes" {
    content = templatefile("${path.module}/../../templates/deploy_kubernetes.sh.tpl", {
    ssh_private_key_path = var.ssh_private_key_path
    admin_user           = var.admin_user
    })
    filename        = "${path.module}/../../../scripts/deploy_kubernetes.sh"
    file_permission = "0755"                                                 
}