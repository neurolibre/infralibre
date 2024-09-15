# Grab information about the image name 
# provided in the local (not version ctrld) main.tf
data "openstack_images_image_v2" "ubuntu" {
  name        = var.image_name
  most_recent = true
}

# =====================================================
# NOTE: We don't create/destroy these network resources
# they pre-exist. Hence, we just grab details to proceed.

# Get details of an existing PUBLIC network
data "openstack_networking_network_v2" "ext_network" {
  name = var.public_network
  external = true
}

# Get details of an existing INTERNAL network
# (that has its subnet) which is connected to the 
# Public-Network via a router.
data "openstack_networking_network_v2" "int_network" {
  name = var.cc_private_network
}
# =====================================================

# See cloud-init/kubeadm directory
data "template_cloudinit_config" "server_config" {
  part {
    filename     = "server-common.yaml"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = data.template_file.server_common.rendered
  }
}


# Grab details of a security group that HAS ALREADY BEEN
# attached to the nfs server (/DATA_NFS)
data "openstack_networking_secgroup_v2" "neurolibre_nfs_secgroup" {
  name = var.nfs_secgroup_name
}

# Create a PORT under the internal network which will be attached to 
# the server VM with the security groups defined here.
resource "openstack_networking_port_v2" "server" {
  name               = "${var.project_name}-${var.server_flavor}-server"
  admin_state_up     = "true"
  network_id         = data.openstack_networking_network_v2.int_network.id
  security_group_ids = [
    openstack_networking_secgroup_v2.common.id,
    data.openstack_networking_secgroup_v2.neurolibre_nfs_secgroup.id
  ]
}

# =====================================================  SERVER VM START
resource "openstack_blockstorage_volume_v3" "servervolume" {
  count       = var.existing_volume_uuid == "" ? 1 : 0
  name        = "${var.project_name}-${var.server_flavor}-volume"
  size        = var.instance_volume_size
  image_id    = data.openstack_images_image_v2.ubuntu.id
}

data "openstack_compute_keypair_v2" "existing_keypair" {
  name = var.existing_keypair_name
}

resource "openstack_compute_instance_v2" "server" {
  name            = "${var.project_name}-${var.server_flavor}-server"
  flavor_name     = var.os_flavor_server
  key_pair        = data.openstack_compute_keypair_v2.existing_keypair.name
  #key_pair        = openstack_compute_keypair_v2.keypair.name
  security_groups = [openstack_networking_secgroup_v2.common.id,
                    data.openstack_networking_secgroup_v2.neurolibre_nfs_secgroup.id]
  user_data       = data.template_cloudinit_config.server_config.rendered

  block_device {
    uuid                  = var.existing_volume_uuid != "" ? var.existing_volume_uuid : openstack_blockstorage_volume_v3.servervolume[0].id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    port = openstack_networking_port_v2.server.id
  }
}
# =====================================================  SERVER VM END


# Create a floating IP in the external network pool
resource "openstack_networking_floatingip_v2" "fip_1" {
  pool = data.openstack_networking_network_v2.ext_network.name
}

# Attached the created floating IP to the PORT with security group
# linked to the server node. So that the floating IP is associated with
# the server node, as well as that secutiry group.
resource "openstack_networking_floatingip_associate_v2" "fip_1" {
  floating_ip = openstack_networking_floatingip_v2.fip_1.address
  port_id     = openstack_networking_port_v2.server.id
}

data "template_file" "server_common" {
  template = file("${path.module}/../../../cloud-init/kubeadm/server-common.yaml")
  vars = {
    ssh_authorized_keys = indent(2, join("\n", formatlist("- %s", var.ssh_authorized_keys)))
    volume_mount_point  = var.volume_mount_point
    volume_device       = var.existing_volume_uuid != "" ? "/dev/disk/by-uuid/${var.existing_volume_uuid}" : "/dev/disk/by-uuid/${openstack_blockstorage_volume_v3.servervolume[0].id}"
  }
}

resource "null_resource" "wait_for_cloud_init" {
  depends_on = [openstack_compute_instance_v2.server]

  connection {
    user        = "ubuntu"
    host        =  openstack_networking_floatingip_v2.fip_1.address
  }

  provisioner "remote-exec" {
    inline = [
      "/usr/bin/cloud-init status --wait"
    ]
  }
}