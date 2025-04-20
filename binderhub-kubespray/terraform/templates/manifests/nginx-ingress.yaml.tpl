rbac:
 create: true
%{ if is_load_balancer ~}
controller:
  service:
    type: LoadBalancer
    loadBalancerIP: ${load_balancer_ip}
  tolerations:
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
  nodeSelector:
    node-role.kubernetes.io/control-plane: ""
%{ else ~}
controller:
  service:
    type: ClusterIP
  tolerations:
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
  nodeSelector:
    node-role.kubernetes.io/control-plane: ""
  kind: DaemonSet
  hostNetwork: true
  config:
    proxy-body-size: 64m
%{ endif ~}
