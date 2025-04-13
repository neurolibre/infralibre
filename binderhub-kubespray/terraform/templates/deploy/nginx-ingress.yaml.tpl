controller:
  service:
    loadBalancerIP: ${load_balancer_ip}
    hostNetwork: true
    annotations:
      metallb.universe.tf/address-pool: public