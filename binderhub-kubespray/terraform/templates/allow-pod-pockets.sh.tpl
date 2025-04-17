#!/bin/bash

# Get all port IDs with this security group
PORT_IDS=$(openstack port list --security-group "${security_group_id}" -c ID -f value)

# Loop and apply allowed IP ranges
for PORT_ID in $PORT_IDS; do
  echo "Updating port: $PORT_ID"
  openstack port set "$PORT_ID" \
    --allowed-address ip-address=${kube_service_addresses} \
    --allowed-address ip-address=${kube_pods_subnet} \
    --allowed-address ip-address=${load_balancer_ip}
  openstack port show "$PORT_ID" -f value -c allowed_address_pairs
done

echo "✅ All matching ports updated."