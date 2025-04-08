all:
  hosts:
    master:
      ansible_host: ${master_ip}
      ip: ${master_private_ip}
      access_ip: ${master_private_ip}
%{ for i, ip in worker_private_ips ~}
    worker-${i}:
      ansible_host: ${ip}
      ip: ${ip}
      access_ip: ${ip}
%{ endfor ~}
  children:
    kube_control_plane:
      hosts:
        master:
    kube_node:
      hosts:
%{ for i, ip in worker_private_ips ~}
        worker-${i}:
%{ endfor ~}
    etcd:
      hosts:
        master:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {} 