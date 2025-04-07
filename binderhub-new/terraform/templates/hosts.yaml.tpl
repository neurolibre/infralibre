all:
  hosts:
    master:
      ansible_host: ${master_ip}
      ip: ${master_private_ip}
      access_ip: ${master_private_ip}
    worker:
      ansible_host: ${worker_ip}
      ip: ${worker_private_ip}
      access_ip: ${worker_private_ip}
  children:
    kube_control_plane:
      hosts:
        master:
    kube_node:
      hosts:
        worker:
    etcd:
      hosts:
        master:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {} 