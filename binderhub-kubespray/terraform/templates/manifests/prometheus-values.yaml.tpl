# Prometheus and Grafana configuration
grafana:
  adminPassword: admin
  ingress:
    hosts:
      - ${grafana_subdomain}.${grafana_domain}
    tls:
      - secretName: grafana-tls
        hosts:
          - ${grafana_subdomain}.${grafana_domain}
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
        - name: prometheus
          orgId: 1
          type: prometheus
          url: ${prometheus_subdomain}.${grafana_domain} 
          access: direct
          isDefault: true
          editable: false

prometheus:
  server:
    persistentVolume:
      size: 1Gi
    ingress:
      hosts:
        - ${prometheus_subdomain}.${grafana_domain}
      tls:
        - secretName: prometheus-tls
          hosts:
            - ${prometheus_subdomain}.${grafana_domain} 