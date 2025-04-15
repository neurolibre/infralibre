---
# Configure Helm
helm_enabled: true

# Configure metrics-server
metrics_server_enabled: true

# Configure cert-manager
cert_manager_enabled: true

metallb_enabled: true
metallb_version: v0.14.9
metallb_namespace: "metallb-system"
metallb_speaker_enabled: true
metallb_ip_range:
  - "${load_balancer_ip}/32"
metallb_protocol: "layer2"
metallb_pool_name: "default"