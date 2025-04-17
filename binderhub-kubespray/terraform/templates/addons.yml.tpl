---
# Configure Helm
helm_enabled: true

# Configure metrics-server
metrics_server_enabled: true

# Configure cert-manager
cert_manager_enabled: true

# Installed using helm
ingress_nginx_enabled: false

metallb_enabled: true
metallb_namespace: metallb-system
metallb_config_file: metallb_config.yaml
metallb_protocol: "layer2"
metallb_ip_range: 
  - ${load_balancer_ip}/32