jupyterhub:
  proxy:
    secretToken: "${secret_token}"
  ingress:
    annotations:
      cert-manager.io/issuer: "letsencrypt-production"
    hosts:
      - ${binderhub_subdomain}.${binderhub_domain}
    tls:
      - secretName: ${cluster_name}-secret-tls
        hosts:
          - ${binderhub_subdomain}.${binderhub_domain}
  #https://discourse.jupyter.org/t/pre-building-images-on-binderhub/4325/4
  prePuller:
    continuous:
      enabled: true
  hub:
    baseUrl: /jupyter/
    config: 
      BinderSpawner:
        cors_allow_origin: '*'
    services:
      binder:
        apiToken: "${api_token}"
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
    startTimeout: 3600 #1h
    extraPodConfig:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: topology.cinder.csi.openstack.org/zone
                    operator: In
                    values:
                      - ${cinder_zone} 
  scheduling:
    corePods:
      nodeAffinity:
        matchNodePurpose: require
      # Allow on tainted nodes
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
    hub_url: https://${binderhub_subdomain}.${binderhub_domain}/jupyter
    cors_allow_origin: '*'
#    badge_base_url: https://${binderhub_subdomain}.${binderhub_domain}
    use_registry: true
    image_prefix: binder-registry.conp.cloud/binder-registry.conp.cloud/binder-

ingress:
  annotations:
    cert-manager.io/issuer: "letsencrypt-production"
  hosts:
    - ${binderhub_subdomain}.${binderhub_domain}
  tls:
    - secretName: ${cluster_name}-secret-tls
      hosts: 
        - ${binderhub_subdomain}.${binderhub_domain}


# Image registry configuration
registry:
  url: ${registry_url}
  username: ${registry_username}
  password: ${registry_password} 