# Get detail of an existing PUBLIC network
data "openstack_networking_network_v2" "network" {
  name           = var.public_network_name
  external       = true
}

# Get details of an existing INTERNAL network
# (that has its subnet) which is connected to the 
# Public-Network via a router.
data "openstack_networking_network_v2" "internal" {
  name = var.internal_network_name
}

# --- Master Port ---
# Create a PORT under the internal network for the master node
resource "openstack_networking_port_v2" "master_port" {
  name           = "${var.cluster_name}-master-port"
  admin_state_up = "true"
  network_id     = data.openstack_networking_network_v2.internal.id
  security_group_ids = [
    openstack_networking_secgroup_v2.k8s_secgroup.id
  ]
  # You might need to specify fixed_ip if your network requires it
  # fixed_ip {
  #   subnet_id = data.openstack_networking_subnet_v2.internal_subnet.id # Requires adding a subnet data source
  # }
}

# Floating IPs
resource "openstack_networking_floatingip_v2" "master_fip" {
  pool = data.openstack_networking_network_v2.network.name  
}