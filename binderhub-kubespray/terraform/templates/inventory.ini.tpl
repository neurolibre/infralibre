[all]
master ansible_host=${master_ip} ip=${master_private_ip} access_ip=${master_private_ip} ansible_user=${admin_user}
%{ for i, ip in worker_private_ips ~}
worker-${i} ansible_host=${ip} ip=${ip} access_ip=${ip} ansible_user=${admin_user} ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -W %h:%p -q ${admin_user}@${master_ip}"'
%{ endfor ~}

[kube_control_plane]
master

[kube_node]
%{ for i, ip in worker_private_ips ~}
worker-${i}
%{ endfor ~}

[etcd]
master

[k8s_cluster:children]
kube_control_plane
kube_node