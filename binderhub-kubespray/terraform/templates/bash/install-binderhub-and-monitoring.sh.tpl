#!/bin/bash

echo "🟢 Starting the deployment script ⎈"

cd /home/${admin_user}/deploy

# Create namespaces
kubectl create namespace binderhub --dry-run=client -o yaml | kubectl apply -f -
#kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Create persistent volume for jupyterhub database.
echo "💾 Creating persistent volume for jupyterhub database"
kubectl apply -f pv-cinder.yaml

# Create Cloudflare API token secret
# Kubespray creates the cert-manager namespace
echo "🔑 Creating Cloudflare API token secret"
kubectl create secret generic cloudflare-api-token-secret --namespace cert-manager --from-literal=api-token=${cloudflare_api_token} --dry-run=client -o yaml | kubectl apply -f -

# Apply the cert-manager issuer
echo "🔑 Applying the cert-manager issuer"
kubectl apply -f production-binderhub-issuer.yaml

# Label master as core node (hub tolerates taints)
echo "🪪 Labeling master as core node"
kubectl label nodes ${cluster_name}-master hub.jupyter.org/node-purpose=core

# Label worker nodes as user nodes
echo "👥 Labeling worker nodes as user nodes"
for i in $(seq 0 $((${worker_count} - 1))); do
  kubectl label nodes ${cluster_name}-worker-$${i} hub.jupyter.org/node-purpose=user
done

echo "⎈ Adding Helm repositories"
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm repo update

%{ if is_load_balancer ~}
echo "⚖️ LoadBalancer enabled, configuring MetalLB for BGP-RR."

kubectl rollout status deployment metallb-controller \
    -n metallb-system --timeout=180s

kubectl rollout status daemonset metallb-speaker \
    -n metallb-system --timeout=180s

kubectl apply -f metallb-bgp.yaml

echo "=============== MetalLB:"
kubectl get all -n metallb-system
%{ endif ~}

echo "⏭ Installing Ingress Nginx into BinderHub namespace"
helm install binderhub-proxy ingress-nginx/ingress-nginx --namespace binderhub -f nginx-ingress.yaml

kubectl wait --namespace binderhub \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo "🌺 Installing BinderHub"
helm install binderhub jupyterhub/binderhub --version=${binderhub_version} --namespace=binderhub -f binderhub-values.yaml -f secrets.yaml

# helm install observability prometheus-community/kube-prometheus-stack --namespace monitoring -f prometheus-values.yaml

echo "Waiting for BinderHub Hub pod..."
kubectl wait --namespace binderhub \
  --for=condition=ready pod \
  --selector=release=binderhub \
  --timeout=120s

echo "=============== Ingress:"
kubectl get ingress -n binderhub

echo "=============== All resources:"
kubectl get all -n binderhub

echo "=============== Cluster issuer:"
kubectl get clusterissuer

echo "=============== Certificates:"
kubectl get certs -n binderhub

echo "🏁 Script complete"
