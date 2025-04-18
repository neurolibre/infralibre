#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# ALLOW POD POCKETS =================================
echo "Allowing pod pockets on all ports within this K8s cluster"
chmod +x scripts/allow-pod-pockets.sh
bash scripts/allow-pod-pockets.sh

# CLONE KUBESPRAY =================================
# - Install requirements (to local python)
# - Install openstackclient (assumes credentials are loaded in local env)
# - Openstackclient is used to allow pod pockets on all ports within this K8s cluster
#   - Only relevant if metallb is enabled, quite troublesome on openstack.

if [ ! -d "kubespray/kubespray" ]; then
    echo "Cloning Kubespray and installing requirements..."
    mkdir -p kubespray
    git clone https://github.com/kubernetes-sigs/kubespray.git kubespray/kubespray
    cd kubespray/kubespray
    git checkout release-2.27
    pip install -r requirements.txt
    pip install python-openstackclient

    # COPY INVENTORY ================================= IMPORTANT
    # - Depends on module.kubespray_config
    echo "Copying inventory to cloned Kubespray"
    mkdir -p inventory/binderhub
    cp -r ../inventory/binderhub/* inventory/binderhub/
    echo "Inventory copied"

    cd ../.. # Return to the project root directory
else
    echo "Kubespray directory already exists. Skipping clone and setup."
    # Optionally add logic here to update inventory if needed on subsequent runs
fi

# RUN KUBESPRAY =================================
echo "Running Kubespray Ansible playbook..."
cd kubespray/kubespray
ansible-playbook -i inventory/binderhub/inventory.ini cluster.yml -b -v \
    --private-key=${ssh_private_key_path} \
    -e ansible_user=${admin_user} | tee ../../ansible-logfile.log

echo "DONE with Kubespray"