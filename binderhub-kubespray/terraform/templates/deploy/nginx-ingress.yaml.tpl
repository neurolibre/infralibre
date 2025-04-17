rbac:
 create: true
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


#controller:
#  service:
#    loadBalancerIP: ${load_balancer_ip}
#  tolerations:
#    - key: "node-role.kubernetes.io/control-plane"
#      operator: "Exists"
#      effect: "NoSchedule"
#  nodeSelector:
#    node-role.kubernetes.io/control-plane: ""