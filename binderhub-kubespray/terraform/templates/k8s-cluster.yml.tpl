# Kubernetes configuration
kube_version: v1.31.4
kube_network_plugin: flannel
kube_proxy_mode: iptables
container_manager: containerd
etcd_deployment_type: host
dns_mode: coredns

# Basic auth for API server
kube_basic_auth: true

# Enable dashboard
dashboard_enabled: true

# Configure Helm
helm_enabled: true

# Configure metrics-server
metrics_server_enabled: true

remove_master_taints: true

# Configure ingress
ingress_nginx_enabled: true
ingress_nginx_host_network: false
ingress_publish_status_address: ""

# Configure cert-manager
cert_manager_enabled: true

# OpenStack Cloud Provider
cloud_provider: external
external_cloud_provider: openstack
external_openstack_auth_url: "${openstack_auth_url}"
external_openstack_username: "${openstack_username}"
external_openstack_password: "${openstack_password}"
external_openstack_domain_name: "${openstack_domain_name}"
external_openstack_project_id: "${openstack_project_id}"
external_openstack_region: "${openstack_region}"
external_openstack_lbaas_subnet_id: "${openstack_subnet_id}"
external_openstack_lbaas_floating_network_id: "${openstack_external_network_id}"
openstack_blockstorage_version: "v3" 