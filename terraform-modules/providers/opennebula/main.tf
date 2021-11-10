provider "opennebula" {
  endpoint = "api's endpoint"
  username = "user's name"
  password = "user's password"
  version = ">= v0.1.1 "
}

data "opennebula_image" "ubuntu" {
  name = "${var.image_name}"
}

resource "opennebula_security_group" "secgroup_1" {
  name        = "${var.project_name}-secgroup"
  description = "BinderHub security group"

  rule {
    range   	= -1:-1
    ip_protocol = "ICMP"
    rule_type	= "INBOUND"
  }

  rule {
    range   	= 1:65535
    ip_protocol = "TCP"
    rule_type	= "INBOUND"
  }

  rule {
    from_port   = 1:65535
    ip_protocol = "UDP"
    rule_type	= "INBOUND"
  }
	
    rule {
    range   	= -1:-1
    ip_protocol = "ICMP"
    ip        	= "192.168.73.30
    size	= "0"
    rule_type	= "INBOUND"
  }

  rule {
    range   	= 1:65535
    ip_protocol = "TCP"
    ip        	= "192.168.73.30
    size	= "0"
    rule_type	= "INBOUND"
  }

  rule {
    range   	= 1:65535
    ip_protocol = "UDP"
    ip        	= "192.168.73.30
    size	= "0"
    rule_type	= "INBOUND"
  }

  rule {
    range   	= 22:22
    ip_protocol = "TCP"
    ip        	= "0.0.0.0
    size	= "4294967295"
    rule_type	= "INBOUND"
  }

  rule {
    range   	= 443:443
    ip_protocol = "TCP"
    ip        	= "0.0.0.0
    size	= "4294967295"
    rule_type	= "INBOUND"
  }

  rule {
    range   	= 80:80
    ip_protocol = "TCP"
    ip        	= "0.0.0.0
    size	= "4294967295"
    rule_type	= "INBOUND"
  }
}

locals {
  network_name = "${var.project_name}-network"
}

resource "opennebula_virtual_network" "network_1" {
    name = "${local.network_name}"
    reservation_vnet = 394
    reservation_size = 1
    security_groups = "${opennebula_security_group.secgroup_1.id}"
}

data "template_file" "kubeadm_master" {
  template = "${file("${path.module}/../../../cloud-init/kubeadm/master.yaml")}"

  vars {
    admin_user      = "${var.admin_user}"
    project_name    = "${var.project_name}"
    nb_nodes 	    = "${var.nb_nodes}"
    docker_registry = "${var.docker_registry}"
    docker_id 	    = "${var.docker_id}"
    docker_password = "${var.docker_password}"
  }
}

data "template_file" "kubeadm_node" {
  template = "${file("${path.module}/../../../cloud-init/kubeadm/node.yaml")}"

  vars {
    master_ip  = "${openstack_compute_instance_v2.master.network.0.fixed_ip_v4}"
    admin_user = "${var.admin_user}"
    docker_registry = "${var.docker_registry}"
    docker_id 	    = "${var.docker_id}"
    docker_password = "${var.docker_password}"
  }
}

data "template_file" "kubeadm_common" {
  template = "${file("${path.module}/../../../cloud-init/kubeadm/common.yaml")}"

  vars {
    ssh_authorized_keys = "${indent(2, join("\n", formatlist("- %s", var.ssh_authorized_keys)))}"
  }
}

data "template_cloudinit_config" "node_config" {
  part {
    filename     = "common.yaml"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = "${data.template_file.kubeadm_common.rendered}"
  }

  part {
    filename     = "node.yaml"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = "${data.template_file.kubeadm_node.rendered}"
  }
}

data "template_cloudinit_config" "master_config" {
  part {
    filename     = "common.yaml"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = "${data.template_file.kubeadm_common.rendered}"
  }

  part {
    filename     = "master.yaml"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = "${data.template_file.kubeadm_master.rendered}"
  }
}

resource "opennebula_virtual_machine" "master" {
  name            = "${var.project_name}-master"
  flavor_name     = "${var.os_flavor_master}"
  key_pair        = "${openstack_compute_keypair_v2.keypair.name}"
  os {
    arch = "x86_64"
  }
  disk {
    image_id	= "${data.opennebula_image.ubuntu.id}"
    size	= "${var.instance_volume_size}"
  }
  context {
    network 	= "YES"
    hostname	= "$NAME"
    user_data	= "${data.template_file.cloudinit.rendered}"
  }
  nic {
    network_id	    = "${opennebula_virtual_network.network_1.id}"
    security_groups = ["${opennebula_security_group.secgroup_1.name}"]
  }
  
}

resource "opennebula_virtual_machine" "node" {
  count    	= "${var.nb_nodes}"
  name     	= "${var.project_name}-node${count.index + 1}"
  flavor_name   = "${var.os_flavor_master}"
  key_pair      = "${openstack_compute_keypair_v2.keypair.name}"
  os {
    arch = "x86_64"
  }
  disk {
    image_id	= "${data.opennebula_image.ubuntu.id}"
    size	= "${var.instance_volume_size}"
  }
  context {
    network 	= "YES"
    hostname	= "$NAME"
    user_data	= "${data.template_file.cloudinit.rendered}"
  }
  nic {
    network_id	    = "${opennebula_virtual_network.network_1.id}"
    security_groups = ["${opennebula_security_group.secgroup_1.name}"]
  }
  
}
  network = {
    name = "${local.network_name}"
  }
}
