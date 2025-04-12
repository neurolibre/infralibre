---
# Configure Helm
helm_enabled: true

# Configure metrics-server
metrics_server_enabled: true

# Configure ingress
# ingress_nginx_enabled: true
# ingress_nginx_host_network: true
# ingress_publish_status_address: ""

# Configure cert-manager
cert_manager_enabled: true

metallb_protocol: "layer2"
metallb_enabled: true
metallb_speaker_enabled: true
metallb_config:
  address_pools:
    production:
      ip_range:
        - ${load_balancer_ip}-${load_balancer_ip}
      auto_assign: false
    default:
      ip_range:
        - 192.168.144.0-192.168.159.255
  layer2:
    - production
    - default