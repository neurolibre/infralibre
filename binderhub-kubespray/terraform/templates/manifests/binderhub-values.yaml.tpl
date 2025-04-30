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
    extraConfig:
      imagePullSecrets: |
        c.KubeSpawner.image_pull_secrets = ['userpull']
  cull:
%{ if binderhub_evidence_type == "preview" ~}
    timeout: 600 #Idle timeout (seconds)
    every: 60 #Interval between checking for idle servers (seconds)
    concurrency: 5 # Number of concurrent API calls to the Hub (default 10)
    maxAge: 3600 #Maximum age of a server before it is culled, even if active (seconds)
%{ else ~}
    timeout: 600 #Idle timeout (seconds)
    every: 60 #Interval between checking for idle servers (seconds)
    concurrency: 8 # Number of concurrent API calls to the Hub (default 10)
    maxAge: 3600 #Maximum age of a server before it is culled, even if active (seconds)
%{ endif ~}
  singleuser:
%{ if binderhub_evidence_type == "preview" ~}
    memory:
       guarantee: 1G
       limit: 3G
    cpu:
       guarantee: 0.5
       limit: 1
    startTimeout: 600 #10min default (seconds)
%{ else ~} # Adjust conditionally.
    memory:
       guarantee: 1G
       limit: 3G
    cpu:
       guarantee: 0.5
       limit: 1
%{ endif ~}
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
    launch_timeout: 600
    retries: 4
    retry_delay: 4
  GitHubRepoProvider:
    banned_specs:
%{ if binderhub_evidence_type == "preprint" ~} # Production accepts only roboneurolibre repositories.
      - ^(?!roboneurolibre\/.*).*
%{endif}
      - ^ines/spacy-binder.*
      - ^soft4voip/rak.*
      - ^hmharshit/cn-ait.*
      - ^shishirchoudharygic/mltraining.*
      - ^hmharshit/mltraining.*
  BinderHub:
    template_path: /etc/binderhub/custom/templates
    hub_url: https://${jupyterhub_subdomain}.${binderhub_domain}
    cors_allow_origin: '*' # Todo: Maybe restrict to neurolibre.org etc
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

initContainers:
  - name: git-clone-templates
    image: alpine/git
    args:
      - clone
      - --single-branch
      - --branch=${binderhub_evidence_type}
      - --depth=1
      - --
      - https://github.com/evidencepub/binder-template
      - /etc/binderhub/custom
    securityContext:
      runAsUser: 0
    volumeMounts:
      - name: custom-templates
        mountPath: /etc/binderhub/custom

extraVolumes:
  - name: custom-templates
    emptyDir: {}
extraVolumeMounts:
  - name: custom-templates
    mountPath: /etc/binderhub/custom
  - name: custom-templates
    mountPath: /usr/local/lib/python3.13/site-packages/binderhub/static/
    subPath: static