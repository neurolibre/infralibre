# BinderHub Helm chart values
jupyterhub:
  hub:
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 1
        memory: 1Gi
    
    services:
      binder:
        apiToken: "REPLACE_WITH_GENERATED_TOKEN"  # Generate a token for production
    
    extraConfig:
      binder: |
        c.KubeSpawner.extra_pod_config.update({
          'tolerations': [{
            'key': 'dedicated',
            'operator': 'Equal',
            'value': 'user',
            'effect': 'NoSchedule'
          }]
        })
  
  singleuser:
    memory:
      limit: 2G
      guarantee: 1G
    cpu:
      limit: 2
      guarantee: 0.5
    storage:
      capacity: 10Gi
  
  proxy:
    service:
      type: ClusterIP
    https:
      enabled: false

binderhub:
  replicas: 1
  
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 1
      memory: 1Gi
  
  extraConfig:
    cors: |
      c.BinderHub.cors_allow_origin = '*'
  
  service:
    type: ClusterIP
  
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - ${binderhub_subdomain}.${domain}
    tls:
      - secretName: binderhub-tls
        hosts:
          - ${binderhub_subdomain}.${domain}

# Image registry configuration
registry:
  url: ${registry_url}
  username: ${registry_username}
  password: ${registry_password} 