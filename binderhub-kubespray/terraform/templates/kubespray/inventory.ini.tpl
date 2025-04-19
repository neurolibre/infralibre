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

%{ if is_load_balancer ~}
[calico_rr]
${cluster_name}-master

[rack0]
${cluster_name}-master
%{ for i, ip in worker_private_ips ~}
${cluster_name}-worker-${i}
%{ endfor ~}

[rack0:vars]
cluster_id="1.0.0.1"
%{ endif ~}

[k8s_cluster:children]
kube_control_plane
kube_node
%{ if is_load_balancer ~}
calico_rr
%{ endif ~}
