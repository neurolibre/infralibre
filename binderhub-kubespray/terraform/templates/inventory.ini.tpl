[all]
${cluster_name}-master ansible_host=${master_ip} ip=${master_private_ip} access_ip=${master_private_ip} ansible_user=${admin_user}
%{ for i, ip in worker_private_ips ~}
${cluster_name}-worker-${i} ansible_host=${ip} ip=${ip} access_ip=${ip} ansible_user=${admin_user} ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -W %h:%p -q ${admin_user}@${master_ip}"'
%{ endfor ~}

[kube_control_plane]
${cluster_name}-master

[kube_node]
%{ for i, ip in worker_private_ips ~}
${cluster_name}-worker-${i}
%{ endfor ~}

[etcd]
${cluster_name}-master

[bastion]
bastion ansible_host=${master_ip} ansible_user=${admin_user}

[calico_rr]

[k8s_cluster:children]
kube_control_plane
kube_node
calico_rr