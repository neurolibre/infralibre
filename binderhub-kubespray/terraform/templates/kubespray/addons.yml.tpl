---
# Configure Helm
helm_enabled: true

# Configure metrics-server
metrics_server_enabled: true

# Configure cert-manager
cert_manager_enabled: true

# Installed using helm
ingress_nginx_enabled: false

%{ if is_load_balancer ~}
metallb_enabled: true
metallb_namespace: metallb-system
metallb_protocol: "bgp"
metallb_ip_range: 
  - ${load_balancer_ip}/32
%{ endif ~}