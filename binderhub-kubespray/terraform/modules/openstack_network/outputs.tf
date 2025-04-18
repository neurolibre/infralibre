output "public_network_id" {
  description = "ID of the public network."
  value       = data.openstack_networking_network_v2.public_network.id
}

output "public_network_name" {
  description = "Name of the public network."
  value       = data.openstack_networking_network_v2.public_network.name
}

output "internal_network_id" {
  description = "ID of the internal network."
  value       = data.openstack_networking_network_v2.internal_network.id
}

output "k8s_sg_id" {
  description = "ID of the Kubernetes cluster security group."
  value       = openstack_networking_secgroup_v2.k8s_secgroup.id
}

output "master_port_id" {
  description = "ID of the pre-created port for the master node."
  value       = openstack_networking_port_v2.master_port.id
}

output "floating_ip" {
  description = "IP address of the master node."
  value       = openstack_networking_floatingip_v2.master_fip.address
}
