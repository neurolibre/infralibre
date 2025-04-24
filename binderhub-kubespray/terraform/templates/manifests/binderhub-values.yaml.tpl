jupyterhub:
  proxy:
    service:
%{ if is_load_balancer ~}
      type: ClusterIP
%{ else ~}
      type: NodePort
%{ endif ~}
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-production
    hosts:
      - ${jupyterhub_subdomain}.${binderhub_domain}
    tls:
      - secretName: ${jupyterhub_subdomain}-secret-tls
        hosts:
          - ${jupyterhub_subdomain}.${binderhub_domain}
  prePuller:
    continuous:
      enabled: true
  hub:
    config:
      BinderSpawner:
        cors_allow_origin: '*'
  cull:
    timeout: 600 #10min
    every: 60
    concurrency: 5
    maxAge: 1800 #30min
  singleuser:
    memory:
       guarantee: 1G
       limit: 3G
    cpu:
       guarantee: 0.5
    startTimeout: 600
    extraPodConfig:
      affinity:
        nodeAffinity:
          required:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-role.kubernetes.io/control-plane
                operator: Exists
  scheduling:
    corePods:
      nodeAffinity:
        matchNodePurpose: require
      # Tolerate the taint on control plane nodes
      tolerations:
        - key: "node-role.kubernetes.io/control-plane"
          operator: "Exists"
          effect: "NoSchedule"
    userPods:
      nodeAffinity:
        matchNodePurpose: prefer

# BinderHub config
config:
  Launcher:
    launch_timeout: 3601 #1h
    retries: 10
    retry_delay: 1
  GitHubRepoProvider:
    banned_specs:
      # - ^(?!neurolibre\/.*).*
      - ^ines/spacy-binder.*
      - ^soft4voip/rak.*
      - ^hmharshit/cn-ait.*
      - ^shishirchoudharygic/mltraining.*
      - ^hmharshit/mltraining.*
  BinderHub:
#    template_path: /etc/binderhub/custom/templates
#    extra_static_path: /etc/binderhub/custom/static
#    extra_static_url_prefix: /extra_static/
#    template_variables:
#        EXTRA_STATIC_URL_PREFIX: "/extra_static/"
    hub_url: https://${jupyterhub_subdomain}.${binderhub_domain}
    cors_allow_origin: '*'
#    badge_base_url: https://${binderhub_subdomain}.${binderhub_domain}
    use_registry: true
    image_prefix: binder-registry.conp.cloud/binder-registry.conp.cloud/binder-

service:
%{ if is_load_balancer ~}
  type: ClusterIP
%{ else ~}
  type: NodePort
%{ endif ~}

ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
  https:
    enabled: true
  hosts:
    - ${binderhub_subdomain}.${binderhub_domain}
  tls:
    - secretName: ${binderhub_subdomain}-secret-tls
      hosts:
        - ${binderhub_subdomain}.${binderhub_domain}