#!/bin/bash

echo "[Binderhub install] Started"

cd /home/${admin_user}/deploy

# Create namespace if it doesn't exist
kubectl create namespace binderhub --dry-run=client -o yaml | kubectl apply -f -

kubectl create -f pv-cinder.yaml

# Create Cloudflare API token secret
kubectl create secret generic cloudflare-api-token-secret --namespace binderhub --from-literal=api-token=${cloudflare_token} --dry-run=client -o yaml | kubectl apply -f -

# Apply the cert-manager issuer
kubectl apply -f production-binderhub-issuer.yaml
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

kubectl label nodes ${cluster_name}-master hub.jupyter.org/node-purpose=core

helm repo add jupyterhub https://jupyterhub.github.io/helm-chart
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install binderhub-proxy ingress-nginx/ingress-nginx --namespace=binderhub -f nginx-ingress.yaml

helm install binderhub jupyterhub/binderhub --version=${binderhub_version} --namespace=binderhub -f binderhub-values.yaml

# helm install observability prometheus-community/kube-prometheus-stack --namespace monitoring -f prometheus-values.yaml