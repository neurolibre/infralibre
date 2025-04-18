#!/bin/bash
set -euxo pipefail

echo "============ 🔧 Configuring kubectl..."
mkdir -p /home/${admin_user}/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/${admin_user}/.kube/config
sudo chown ${admin_user}:${admin_user} /home/${admin_user}/.kube/config
echo "============ 🎉 kubectl configured successfully"
mkdir -p /home/${admin_user}/deploy
echo "============ 🎉 Created deploy directory"