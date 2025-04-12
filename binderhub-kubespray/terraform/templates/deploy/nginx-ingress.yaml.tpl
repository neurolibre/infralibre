controller:
  serviceAccount:
    create: true
  rbac:
    create: true
  service:
    loadBalancerIP: ${load_balancer_ip}
    hostNetwork: true
    type: LoadBalancer
    annotations:
      metallb.universe.tf/address-pool: production