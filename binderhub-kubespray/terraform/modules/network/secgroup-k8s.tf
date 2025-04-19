# Security groups
resource "openstack_networking_secgroup_v2" "k8s_secgroup" {
  name        = "${var.cluster_name}-secgroup"
  description = "${formatdate("YYYY-MM-DD", timestamp())} Security group for Kubernetes cluster and binderhub"
}

# ICMP specific
resource "openstack_networking_secgroup_rule_v2" "icmp_self" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_group_id   = openstack_networking_secgroup_v2.k8s_secgroup.id
}

# TCP specific
resource "openstack_networking_secgroup_rule_v2" "tcp_self" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_group_id   = openstack_networking_secgroup_v2.k8s_secgroup.id
}

# UDP specific
resource "openstack_networking_secgroup_rule_v2" "udp_self" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_group_id   = openstack_networking_secgroup_v2.k8s_secgroup.id
}

# ================================ K8s service and pod subnets
# Service subnet
resource "openstack_networking_secgroup_rule_v2" "k8s_service_subnet" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_ip_prefix  = var.kube_service_addresses
}

# Pod subnet
resource "openstack_networking_secgroup_rule_v2" "k8s_pod_subnet" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_ip_prefix  = var.kube_pods_subnet
}
# ================================

# ================================ Internal network
# Needed to allow the cluster to communicate with VMs that are not part of the cluster
# such as the NFS server.
resource "openstack_networking_secgroup_rule_v2" "tcp_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_ip_prefix  = var.internal_network_cidr
}

# UDP specific
resource "openstack_networking_secgroup_rule_v2" "udp_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_ip_prefix  = var.internal_network_cidr
}

# UDP specific
resource "openstack_networking_secgroup_rule_v2" "icmp_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_ip_prefix  = var.internal_network_cidr
}
# ================================

# ================================ External network SSH, HTTP, HTTPS
# SSH port
resource "openstack_networking_secgroup_rule_v2" "tcp_22" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_ip_prefix  = "0.0.0.0/0"
}

# HTTP and HTTPS ports
resource "openstack_networking_secgroup_rule_v2" "tcp_443" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "tcp_80" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_ip_prefix  = "0.0.0.0/0"
}