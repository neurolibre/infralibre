# --- Image Lookup ---
data "openstack_images_image_v2" "image" {
  name        = var.image_name
}

# --- Keypair ---
# Create a keypair for each SSH key provided
# Note: OpenStack instances usually only take *one* keypair at creation.
# Cloud-init handles adding *all* keys from var.ssh_authorized_keys.
# We create multiple keypair resources in OpenStack mainly for reference/management,
# but only assign the first one to the instance resource.
resource "openstack_compute_keypair_v2" "keypair" {
  count      = length(var.ssh_authorized_keys)
  name       = "${var.cluster_name}-keypair-${count.index}"
  public_key = var.ssh_authorized_keys[count.index]
}

# --- Cloud-Init Configuration ---
# Note: The template file path assumes it stays in the root module's templates dir.
# If you move the template into this module, change the path accordingly.
data "template_file" "cloud_init_cluster" {
  template = file("${path.module}/../../templates/compute/cloud-init-cluster.yml.tpl") # Path relative to this module file
  vars = {
    ssh_authorized_keys = indent(2, join("\n", formatlist("- %s", var.ssh_authorized_keys)))
    ceph_rule_name = var.ceph_rule_name
    ceph_rule_key = var.ceph_rule_key
    ceph_share_hash = var.ceph_share_hash
    admin_user = var.admin_user
    etcd_volume_device = "/dev/disk/by-uuid/${openstack_blockstorage_volume_v3.etcd_volume.id}"
    cluster_name = var.cluster_name
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

# --- Master Node ---
resource "openstack_compute_instance_v2" "master" {
  name            = "${var.cluster_name}-master"
  image_id        = data.openstack_images_image_v2.image.id
  flavor_name     = var.flavor_master
  # Use only the first keypair for OpenStack instance creation
  key_pair        = openstack_compute_keypair_v2.keypair[0].name
  security_groups = var.network_security_group_ids
  user_data       = data.template_cloudinit_config.cluster_config.rendered

  network {
    port = var.network_master_port_id
  }

  metadata = {
    role = "master"
    # Add any other relevant metadata
  }

  depends_on = [openstack_compute_keypair_v2.keypair, openstack_blockstorage_volume_v3.etcd_volume]
}

# --- Worker Nodes ---
resource "openstack_compute_instance_v2" "worker" {
  count           = var.worker_count
  name            = "${var.cluster_name}-worker-${count.index}"
  image_id        = data.openstack_images_image_v2.image.id
  flavor_name     = var.flavor_worker
  key_pair        = openstack_compute_keypair_v2.keypair[0].name
  security_groups = var.network_security_group_ids
  user_data       = data.template_cloudinit_config.cluster_config.rendered

  network {
    uuid = var.network_internal_id # Attach directly to internal network
  }

  metadata = {
    role = "worker-${count.index}"
  }

  depends_on = [openstack_compute_keypair_v2.keypair]
}

# resource "openstack_compute_floatingip_associate_v2" "master_fip_associate" {
#   floating_ip = var.network_floating_ip
#   instance_id = openstack_compute_instance_v2.master.id

#   # Ensure the master instance exists before associating
#   depends_on = [openstack_compute_instance_v2.master]
# }

# --- Cinder Volume ---
# https://jupyterhub.readthedocs.io/en/latest/explanation/database.html
# Cinder volume to be bound by the JupyterHub pod
resource "openstack_blockstorage_volume_v3" "hub_db_volume" {
  name              = "${var.cluster_name}-hub-db"
  size              = var.cinder_volume_size
  description       = "Cinder volume for JupyterHub DB"
  availability_zone = var.cinder_availability_zone
}

# --- Etcd Volume ---
resource "openstack_blockstorage_volume_v3" "etcd_volume" {
  name              = "${var.cluster_name}-etcd"
  size              = 8
  description       = "Cinder volume for etcd"
  availability_zone = var.cinder_availability_zone
}

resource "terraform_data" "wait_for_cloud_init_on_all_nodes" {
  count = length(concat([openstack_compute_instance_v2.master.network.0.fixed_ip_v4], [for worker in openstack_compute_instance_v2.worker : worker.network.0.fixed_ip_v4]))

  depends_on = [
    openstack_compute_instance_v2.master,
    openstack_compute_instance_v2.worker
  ]

  connection {
    type        = "ssh"
    user        = var.admin_user
    host        = element(concat(
      [openstack_compute_instance_v2.master.network.0.fixed_ip_v4],
      [for worker in openstack_compute_instance_v2.worker : worker.network.0.fixed_ip_v4]
    ), count.index)
    timeout     = "10m"
    bastion_host = var.network_floating_ip
    bastion_user = var.admin_user
  }

  # Check if cloud-init has completed
  provisioner "remote-exec" {
    inline = [
      "echo '⏳ Waiting for cloud-init to complete (${count.index})...'",
      "cloud-init status --wait >> /dev/null",
      "echo '✅ Cloud-init completed successfully'",
    ]
  }
}

# resource "terraform_data" "wait_for_workers_cloud_init" {
#   count = var.worker_count
  
#   depends_on = [
#     openstack_compute_instance_v2.worker,
#     terraform_data.wait_for_cloud_init_master
#   ]

#   connection {
#     type        = "ssh"
#     user        = var.admin_user
#     host        = openstack_compute_instance_v2.worker[count.index].network.0.fixed_ip_v4
#     timeout     = "10m"
#     bastion_host = var.network_floating_ip
#     bastion_user = var.admin_user
#   }

#   # Check if cloud-init has completed
#   provisioner "remote-exec" {
#     inline = [
#       "echo '⏲️ Waiting for cloud-init to complete on worker node ${count.index}...'",
#       "cloud-init status --wait >> /dev/null",
#       "echo '✅ Cloud-init completed successfully on worker node ${count.index}'",
#     ]
#   }
# }

# Ensure SSH keys are properly set up
resource "terraform_data" "prepare_ssh_environment" {
  depends_on = [
    terraform_data.wait_for_cloud_init_on_all_nodes
  ]

  provisioner "local-exec" {
    command = <<-EOT
      # Add master to known hosts
      ssh-keyscan -H ${var.network_floating_ip} >> ~/.ssh/known_hosts
      
      # Test SSH to master
      ssh -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} ${var.admin_user}@${var.network_floating_ip} echo "SSH to master successful"
      
      # Test SSH to workers through bastion (master)
      for ip in ${join(" ", [for worker in openstack_compute_instance_v2.worker : worker.network.0.fixed_ip_v4])}; do
        echo "🔑 Testing SSH to worker $ip through master..."
        ssh -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} -o ProxyCommand="ssh -i ${var.ssh_private_key_path} -W %h:%p ${var.admin_user}@${var.network_floating_ip}" ${var.admin_user}@$ip echo "SSH to worker $ip successful"
      done
    EOT
  }
}