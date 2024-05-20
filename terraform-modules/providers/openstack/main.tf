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

# Cloud-init configs for the worker node(s)
# See cloud-init/kubeadm directory
# Common.yaml + node.yaml
data "template_cloudinit_config" "node_config" {
  count = var.nb_nodes

  part {
    filename     = "common.yaml"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = data.template_file.kubeadm_common.rendered
  }

  part {
    filename     = "node.yaml"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = data.template_file.kubeadm_node.rendered
  }
}

# Cloud-init configs for the master node
# See cloud-init/kubeadm directory
# Common.yaml + master.yaml
data "template_cloudinit_config" "master_config" {
  part {
    filename     = "common.yaml"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = data.template_file.kubeadm_common.rendered
  }

  part {
    filename     = "master.yaml"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = data.template_file.kubeadm_master.rendered
  }
}

# Create a keypair to be shared across nodes 
# This is the first entry of the ssh_authorized_keys
# This is passed from main.tf LOCALLY (not version controlled)
resource "openstack_compute_keypair_v2" "keypair" {
  name       = "${var.project_name}-keypair-ed25519"
  public_key = element(var.ssh_authorized_keys, 0)
}

# Grab details of a security group that HAS ALREADY BEEN
# attached to the sftp instance (/DATA)
data "openstack_networking_secgroup_v2" "neurolibre_sftp_secgroup" {
  name = var.sftp_secgroup_name
}


# Create a PORT under the internal network which will be attached to 
# the master node with the security groups defined here.
resource "openstack_networking_port_v2" "master" {
  name               = "${var.project_name}-master"
  admin_state_up     = "true"
  network_id         = data.openstack_networking_network_v2.int_network.id
  security_group_ids = [
    openstack_networking_secgroup_v2.common.id,
    data.openstack_networking_secgroup_v2.neurolibre_sftp_secgroup.id
  ]
}

# =====================================================  MASTER NODE START
# Create a volume for the master node
resource "openstack_blockstorage_volume_v3" "mastervolume" {
  name        = "master-volume"
  size        = var.instance_volume_size
  image_id    = data.openstack_images_image_v2.ubuntu.id
}

# Create the master node
resource "openstack_compute_instance_v2" "master" {
  name            = "${var.project_name}-master"
  flavor_name     = var.os_flavor_master
  key_pair        = openstack_compute_keypair_v2.keypair.name
  security_groups = [openstack_networking_secgroup_v2.common.id,
                    data.openstack_networking_secgroup_v2.neurolibre_sftp_secgroup.id]
  user_data       = data.template_cloudinit_config.master_config.rendered

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.mastervolume.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    port = openstack_networking_port_v2.master.id
  }
}
# =====================================================  MASTER NODE ENDD



# ===================================================== WORKER NODE(S) START
# Create worker node storage volume(s). The number of worker volumes is 
# defined by the count
resource "openstack_blockstorage_volume_v3" "nodevolume" {
  count = var.nb_nodes
  name        = format("node-%02d-volume", count.index + 1)
  size        = var.instance_volume_size
  image_id    = data.openstack_images_image_v2.ubuntu.id
}

# Create workers node(s). The number of worker nodes is 
# defined by the count
resource "openstack_compute_instance_v2" "node" {
  count = var.nb_nodes
  name  = "${var.project_name}-node${count.index + 1}"

  flavor_name     = var.os_flavor_node
  key_pair        = openstack_compute_keypair_v2.keypair.name
  security_groups = [openstack_networking_secgroup_v2.common.id,
                    data.openstack_networking_secgroup_v2.neurolibre_sftp_secgroup.id]
  user_data =element(
              data.template_cloudinit_config.node_config.*.rendered,
              count.index,)



  block_device {
    uuid                  = openstack_blockstorage_volume_v3.nodevolume[count.index].id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    name = var.is_computecanada ? data.openstack_networking_network_v2.int_network.name : "${var.project_name}-network"
  }
}
# ===================================================== WORKER NODE(S) END

# Create a floating IP in the external network pool
resource "openstack_networking_floatingip_v2" "fip_1" {
  pool = data.openstack_networking_network_v2.ext_network.name
}

# Attached the created floating IP to the PORT with security group
# linked to the master node. So that the floating IP is associated with
# the master node, as well as that secutiry group.
resource "openstack_networking_floatingip_associate_v2" "fip_1" {
  floating_ip = openstack_networking_floatingip_v2.fip_1.address
  port_id     = openstack_networking_port_v2.master.id
}


# Pass the keys provided in the local main.tf
# to create a master.yaml template config on the 
# instantiated VM.
data "template_file" "kubeadm_master" {
  template = file("${path.module}/../../../cloud-init/kubeadm/master.yaml")

  vars = {
    sftp_ip         = var.sftp_ip_address
    sftp_dir        = var.sftp_mnt_dir
    admin_user      = var.admin_user
    project_name    = var.project_name
    nb_nodes        = var.nb_nodes
    docker_registry = var.docker_registry
    docker_id       = var.docker_id
    docker_password = var.docker_password
  }
}

# Do the same for node.yaml (worker node exclusive)
data "template_file" "kubeadm_node" {
  template = file("${path.module}/../../../cloud-init/kubeadm/node.yaml")
  vars = {
    master_ip       = openstack_compute_instance_v2.master.access_ip_v4
    sftp_ip         = var.sftp_ip_address
    sftp_dir         = var.sftp_mnt_dir
    admin_user      = var.admin_user
    docker_registry = var.docker_registry
    docker_id       = var.docker_id
    docker_password = var.docker_password
  }
}

# Do the same for common.yaml
data "template_file" "kubeadm_common" {
  template = file("${path.module}/../../../cloud-init/kubeadm/common.yaml")
  vars = {
    ssh_authorized_keys = indent(2, join("\n", formatlist("- %s", var.ssh_authorized_keys)))
  }
}


# # ================================================== OpenNebula attemps
# # Define a network, only if not using Compute Canada
# resource "openstack_networking_subnet_v2" "subnet" {
#   count = var.is_computecanada ? 0 : 1

#   name        = "subnet"
#   network_id  = openstack_networking_network_v2.network_1[0].id
#   ip_version  = 4
#   cidr        = "10.0.1.0/24"
#   enable_dhcp = true
# }

# # Define a subnet within the network, only if not using Compute Canada
# resource "openstack_networking_network_v2" "network_1" {
#   count = var.is_computecanada ? 0 : 1
#   name = "${var.project_name}-network"
# }

# # Define a router, only if not using Compute Canada
# resource "openstack_networking_router_v2" "router_1" {
#   count = var.is_computecanada ? 0 : 1

#   name                = "${var.project_name}-router"
#   external_network_id = data.openstack_networking_network_v2.ext_network.id
# }

# # Attach the subnet to the router, only if not using Compute Canada
# resource "openstack_networking_router_interface_v2" "router_interface_1" {
#   count = var.is_computecanada ? 0 : 1
#   router_id = openstack_networking_router_v2.router_1[0].id
#   subnet_id = openstack_networking_subnet_v2.subnet[0].id
# }
# # ==================================================