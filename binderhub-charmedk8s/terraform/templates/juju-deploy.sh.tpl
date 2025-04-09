#!/bin/bash
set -e

# Bootstrap Juju controller
juju bootstrap openstack ${cluster_name}-controller --config-file=/home/${admin_user}/juju/config.yaml

# Add Kubernetes model
juju add-model k8s

# Add all machines to Juju
echo "Adding machines to Juju..."
# Add master node
MASTER_MACHINE_ID=$(juju add-machine ssh:${admin_user}@${master_private_ip} | grep -o '[0-9]*')
echo "Added master machine with ID: $MASTER_MACHINE_ID"

# Add worker nodes
WORKER_MACHINE_IDS=()
%{ for ip in worker_private_ips ~}
WORKER_ID=$(juju add-machine ssh:${admin_user}@${ip} | grep -o '[0-9]*')
WORKER_MACHINE_IDS+=($WORKER_ID)
echo "Added worker machine with ID: $WORKER_ID"
%{ endfor ~}

# Deploy Charmed Kubernetes
echo "Deploying Charmed Kubernetes..."
juju deploy charmed-kubernetes --overlay=/home/${admin_user}/juju/openstack-overlay.yaml

# Place applications on specific machines
echo "Placing applications on machines..."
# Place control plane components on master
juju deploy kubernetes-control-plane --to $MASTER_MACHINE_ID
juju deploy etcd --to $MASTER_MACHINE_ID
juju deploy openstack-integrator --to $MASTER_MACHINE_ID

# Place worker components on worker nodes
for i in "$${!WORKER_MACHINE_IDS[@]}"; do
  juju deploy kubernetes-worker --to $${WORKER_MACHINE_IDS[$i]}
done

# Add relations
echo "Adding relations between components..."
juju relate kubernetes-control-plane:kube-api-endpoint kubernetes-worker:kube-api-endpoint
juju relate kubernetes-control-plane:kube-control kubernetes-worker:kube-control
juju relate kubernetes-control-plane:certificates easyrsa:client
juju relate kubernetes-worker:certificates easyrsa:client
juju relate etcd:certificates easyrsa:client
juju relate kubernetes-control-plane:etcd etcd:db

# Add OpenStack integration
juju relate openstack-integrator:clients kubernetes-control-plane:openstack
juju relate openstack-integrator:clients kubernetes-worker:openstack

echo "Waiting for deployment to complete..."
juju wait-for application kubernetes-control-plane --timeout=30m
juju wait-for application kubernetes-worker --timeout=30m

# Configure kubectl
echo "Configuring kubectl..."
mkdir -p /home/${admin_user}/.kube
juju ssh kubernetes-control-plane/leader -- cat config > /home/${admin_user}/.kube/config
chmod 600 /home/${admin_user}/.kube/config
chown ${admin_user}:${admin_user} /home/${admin_user}/.kube/config