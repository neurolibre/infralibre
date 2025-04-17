#!/bin/bash

echo "[Binderhub install] Started"

cd /home/${admin_user}/deploy

# Create namespaces
kubectl create namespace binderhub --dry-run=client -o yaml | kubectl apply -f -
#kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
# kubectl create namespace metallb-system --dry-run=client -o yaml | kubectl apply -f -

# Create persistent volume for jupyterhub database.
kubectl apply -f pv-cinder.yaml

# Create Cloudflare API token secret
# Kubespray creates the cert-manager namespace
kubectl create secret generic cloudflare-api-token-secret --namespace cert-manager --from-literal=api-token=${cloudflare_token} --dry-run=client -o yaml | kubectl apply -f -

# Apply the cert-manager issuer
kubectl apply -f production-binderhub-issuer.yaml

# Label master as core node (hub tolerates taints)
kubectl label nodes ${cluster_name}-master hub.jupyter.org/node-purpose=core

# Label worker nodes as user nodes
for i in $(seq 0 $((${worker_count} - 1))); do
  kubectl label nodes ${cluster_name}-worker-$${i} hub.jupyter.org/node-purpose=user
done

helm repo add jupyterhub https://jupyterhub.github.io/helm-chart
# sudo helm repo add metallb https://metallb.github.io/metallb
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

sudo helm repo update

# echo "Installing MetalLB using Helm..."
#sudo helm install metallb metallb/metallb -n metallb-system

# echo "Waiting for MetalLB controller..."
# kubectl rollout status deployment metallb-controller \
#     -n metallb-system --timeout=180s

# echo "Waiting for MetalLB speaker..."
# kubectl rollout status daemonset metallb-speaker \
#     -n metallb-system --timeout=180s

# kubectl apply -f metallb_ipaddresspool.yaml
# kubectl apply -f metallb_l2advertisement.yaml
# kubectl apply -f metallb-bgp.yaml

echo "Installing Ingress Nginx..."
helm install binderhub-proxy ingress-nginx/ingress-nginx --namespace binderhub -f nginx-ingress.yaml

kubectl wait --namespace binderhub \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo "Installing BinderHub..."
helm install binderhub jupyterhub/binderhub --version=${binderhub_version} --namespace=binderhub -f binderhub-values.yaml

# helm install observability prometheus-community/kube-prometheus-stack --namespace monitoring -f prometheus-values.yaml

echo "Waiting for BinderHub Hub pod..."
kubectl wait --namespace binderhub \
  --for=condition=ready pod \
  --selector=release=binderhub \
  --timeout=120s

echo "BinderHub Ingress Service:"
kubectl get services --namespace binderhub binderhub-proxy-ingress-nginx-controller -o wide

echo "[Binderhub install] end of script"