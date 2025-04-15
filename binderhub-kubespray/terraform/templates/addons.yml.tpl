---
# Configure Helm
helm_enabled: true

# Configure metrics-server
metrics_server_enabled: true

# Configure cert-manager
cert_manager_enabled: true

metallb_enabled: true
metallb_namespace: "metallb-system"
metallb_speaker_enabled: true
kube_proxy_strict_arp: true
metallb_config:
  address_pools:
    primary:
      ip_range:
        - "${load_balancer_ip}/32"
  layer2:
    - primary