# Security groups
resource "openstack_networking_secgroup_v2" "k8s_secgroup" {
  name        = "${var.cluster_name}-secgroup"
  description = "${formatdate("YYYY-MM-DD", timestamp())} Security group for Kubernetes cluster and binderhub"
}

resource "openstack_networking_secgroup_rule_v2" "icmp_self" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_group_id   = openstack_networking_secgroup_v2.k8s_secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "tcp_self" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_group_id   = openstack_networking_secgroup_v2.k8s_secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "udp_self" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_group_id   = openstack_networking_secgroup_v2.k8s_secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "icmp_specific" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_ip_prefix  = "192.168.73.30/32"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_service_subnet" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_ip_prefix  = "10.233.0.0/18"
}

resource "openstack_networking_secgroup_rule_v2" "k8s_pod_subnet" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_ip_prefix  = "10.233.64.0/18"
}

resource "openstack_networking_secgroup_rule_v2" "tcp_specific" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_ip_prefix  = "192.168.73.30/32"
}

resource "openstack_networking_secgroup_rule_v2" "udp_specific" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 0
  port_range_max    = 0
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_ip_prefix  = "192.168.73.30/32"
}

resource "openstack_networking_secgroup_rule_v2" "tcp_22" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
  remote_ip_prefix  = "0.0.0.0/0"
}

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