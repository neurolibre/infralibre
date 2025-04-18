output "master_instance_id" {
  description = "ID of the master compute instance."
  value       = openstack_compute_instance_v2.master.id
}

output "master_private_ip" {
  description = "Private IP address of the master node."
  # Accessing network data requires the instance resource to be fully created.
  # The exact index [0] might depend on your network configuration.
  value = openstack_compute_instance_v2.master.network[0].fixed_ip_v4
}

output "master_floating_ip" {
  description = "Public floating IP address associated with the master node."
  value       = openstack_networking_floatingip_v2.master_fip.address
}

output "worker_instance_ids" {
  description = "List of IDs of the worker compute instances."
  value       = [for worker in openstack_compute_instance_v2.worker : worker.id]
}

output "worker_private_ips" {
  description = "List of private IP addresses of the worker nodes."
  value       = [for worker in openstack_compute_instance_v2.worker : worker.network[0].fixed_ip_v4]
}

output "hub_db_volume_id" {
  description = "ID of the Cinder volume created for the Hub database."
  value       = openstack_blockstorage_volume_v3.hub_db_volume.id
}

output "keypair_names" {
  description = "List of names of the created OpenStack keypairs."
  value       = [for kp in openstack_compute_keypair_v2.keypair : kp.name]
}

output "cloud_init_rendered" {
  description = "Rendered cloud-init config (useful for debugging)."
  value       = data.template_cloudinit_config.cluster_config.rendered
  sensitive   = true # Mark sensitive if SSH keys make it sensitive
}