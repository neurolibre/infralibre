# Prometheus and Grafana configuration
grafana:
  adminPassword: admin
  service:
    type: ClusterIP
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: letsencrypt-production
    hosts:
      - ${grafana_subdomain}.${grafana_domain}
    tls:
      - secretName: grafana-tls
        hosts:
          - ${grafana_subdomain}.${grafana_domain}

prometheus:
  service:
    type: ClusterIP
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: letsencrypt-production
    hosts:
      - ${prometheus_subdomain}.${grafana_domain}
    tls:
      - secretName: prometheus-tls
        hosts:
          - ${prometheus_subdomain}.${grafana_domain} 