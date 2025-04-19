#!/bin/bash

# Get all port IDs with this security group
PORT_IDS=$(openstack port list --security-group "${security_group_id}" -c ID -f value)

# Loop and apply allowed IP ranges
# Relevant sources:
# - https://that.guru/blog/deploying-metallb-on-openstack-part-2/
# https://kubespray.io/#/docs/cloud_controllers/openstack?id=additional-step-needed-when-using-calico-or-kube-router 

%{ if is_load_balancer ~}
echo "⚖️ Updating ports with load balancer IP"
for PORT_ID in $PORT_IDS; do
  echo "ℹ️ Updating port: $PORT_ID"
  openstack port set "$PORT_ID" \
    --allowed-address ip-address=${kube_service_addresses} \
    --allowed-address ip-address=${kube_pods_subnet} \
    --allowed-address ip-address=${load_balancer_ip}
  openstack port show "$PORT_ID" -f value -c allowed_address_pairs
done
%{ else ~}
echo "🔗 Updating ports for Calico only"
for PORT_ID in $PORT_IDS; do
  echo "ℹ️ Updating port: $PORT_ID"
  openstack port set "$PORT_ID" \
    --allowed-address ip-address=${kube_service_addresses} \
    --allowed-address ip-address=${kube_pods_subnet}
done
%{ endif ~}
echo "✅ All matching ports updated."