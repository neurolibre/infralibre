description: Charmed Kubernetes overlay to add native OpenStack support.
applications:
  kubernetes-control-plane:
    options:
      allow-privileged: "true"
  openstack-integrator:
    charm: openstack-integrator
    num_units: 1
    trust: true
  openstack-cloud-controller:
    charm: openstack-cloud-controller
  cinder-csi:
    charm: cinder-csi
  kubeapi-load-balancer:
    charm: kubeapi-load-balancer
    num_units: 3
  keepalived:
    charm: keepalived
relations:
  - [openstack-cloud-controller:certificates, easyrsa:client]
  - [openstack-cloud-controller:kube-control, kubernetes-control-plane:kube-control]
  - [openstack-cloud-controller:external-cloud-provider, kubernetes-control-plane:external-cloud-provider]
  - [openstack-cloud-controller:openstack, openstack-integrator:clients]
  - [easyrsa:client, cinder-csi:certificates]
  - [kubernetes-control-plane:kube-control, cinder-csi:kube-control]
  - [openstack-integrator:clients, cinder-csi:openstack]
  - [keepalived:juju-info, kubeapi-load-balancer:juju-info]
  - [keepalived:lb-sink, kubeapi-load-balancer:website]
  - [keepalived:loadbalancer, kubernetes-control-plane:loadbalancer]
  - [keepalived:website, kubernetes-worker:kube-api-endpoint]