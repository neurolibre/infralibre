# Kubernetes configuration
kube_version: v1.26.5
kube_network_plugin: calico
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

# Configure ingress
ingress_nginx_enabled: true
ingress_nginx_host_network: false
ingress_publish_status_address: ""

# Configure cert-manager
cert_manager_enabled: true 