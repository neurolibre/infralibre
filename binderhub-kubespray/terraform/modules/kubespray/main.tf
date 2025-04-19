    # Read OpenStack environment variables
    # Note: This assumes the machine running Terraform has the OS_ env vars set.
    data "external" "openstack_env" {
      program = ["bash", "-c", "env | grep OS_ | sed 's/^/\"/;s/=/\":\"/;s/$/\",/' | tr -d '\\n' | sed 's/,$//' | echo '{' $(cat) '}'"]
    }

    # Generate Kubespray inventory
    resource "local_file" "kubespray_inventory" {
      content = templatefile("${path.module}/../../templates/kubespray/inventory.ini.tpl", {
        cluster_name       = var.cluster_name
        master_ip          = var.master_floating_ip
        master_private_ip  = var.master_private_ip
        worker_private_ips = var.worker_private_ips
        admin_user         = var.admin_user
        is_load_balancer   = var.is_load_balancer
      })
      filename = "${path.module}/../../../kubespray/inventory/binderhub/inventory.ini" # Adjusted path
    }

    resource "local_file" "k8s_cluster_vars" {
      content = templatefile("${path.module}/../../templates/kubespray/k8s-cluster.yml.tpl", {
        kube_service_addresses = var.kube_service_addresses
        kube_pods_subnet       = var.kube_pods_subnet
        k8s_version            = var.k8s_version
        is_load_balancer       = var.is_load_balancer
      })
      filename = "${path.module}/../../../kubespray/inventory/binderhub/group_vars/k8s_cluster/k8s-cluster.yml" # Adjusted path

      depends_on = [local_file.kubespray_inventory] # Ensure inventory exists first
    }

    resource "local_file" "addons" {
      content = templatefile("${path.module}/../../templates/kubespray/addons.yml.tpl", {
        load_balancer_ip = var.master_floating_ip
        is_load_balancer = var.is_load_balancer
      })
      filename = "${path.module}/../../../kubespray/inventory/binderhub/group_vars/k8s_cluster/addons.yml" # Adjusted path

      depends_on = [local_file.kubespray_inventory]
    }

    resource "local_file" "openstack" {
      content = templatefile("${path.module}/../../templates/kubespray/openstack.yml.tpl", {
        openstack_username            = data.external.openstack_env.result["OS_USERNAME"]
        openstack_password            = data.external.openstack_env.result["OS_PASSWORD"]
        openstack_project_id          = data.external.openstack_env.result["OS_PROJECT_ID"]
        openstack_auth_url            = data.external.openstack_env.result["OS_AUTH_URL"]
        openstack_region              = data.external.openstack_env.result["OS_REGION_NAME"]
        openstack_project_name        = data.external.openstack_env.result["OS_PROJECT_NAME"]
        openstack_domain_name         = data.external.openstack_env.result["OS_USER_DOMAIN_NAME"]
        openstack_subnet_id           = var.openstack_internal_network_id # Check if Kubespray needs network or subnet ID
        openstack_external_network_id = var.openstack_public_network_id
      })
      filename = "${path.module}/../../../kubespray/inventory/binderhub/group_vars/all/openstack.yml" # Adjusted path

      depends_on = [local_file.kubespray_inventory]
    }

    resource "local_file" "all_vars" {
      content  = templatefile("${path.module}/../../templates/kubespray/all.yml.tpl", {})
      filename = "${path.module}/../../../kubespray/inventory/binderhub/group_vars/all/all.yml" # Adjusted path

      depends_on = [local_file.kubespray_inventory]
    }