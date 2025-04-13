#!/bin/bash

echo "[Binderhub install] Started"

cd /home/${admin_user}/deploy

# Create namespaces
kubectl create namespace binderhub --dry-run=client -o yaml | kubectl apply -f -
#kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace metallb-system --dry-run=client -o yaml | kubectl apply -f -

# Create persistent volume for jupyterhub database.
kubectl create -f pv-cinder.yaml

# Create Cloudflare API token secret
kubectl create secret generic cloudflare-api-token-secret --namespace binderhub --from-literal=api-token=${cloudflare_token} --dry-run=client -o yaml | kubectl apply -f -

# Apply the cert-manager issuer
kubectl apply -f production-binderhub-issuer.yaml

# Label master as core node (hub tolerates taints)
kubectl label nodes ${cluster_name}-master hub.jupyter.org/node-purpose=core

# Label worker nodes as user nodes
for i in $(seq 0 $((${worker_count} - 1))); do
  kubectl label nodes ${cluster_name}-worker-\${i} hub.jupyter.org/node-purpose=user
done

helm repo add jupyterhub https://jupyterhub.github.io/helm-chart
helm repo add metallb https://metallb.github.io/metallb
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx


kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install metallb metallb/metallb -n metallb-system
kubectl apply -f metallb_ipaddresspool.yaml
kubectl apply -f metallb_l2advertisement.yaml

helm install binderhub-proxy ingress-nginx/ingress-nginx --namespace=binderhub -f nginx-ingress.yaml
helm install binderhub jupyterhub/binderhub --version=${binderhub_version} --namespace=binderhub -f binderhub-values.yaml

# helm install observability prometheus-community/kube-prometheus-stack --namespace monitoring -f prometheus-values.yaml