#!/bin/bash
set -euo pipefail

# Function to check if a namespace exists
namespace_exists() {
    kubectl get namespace "$1" &> /dev/null
}

# Function to apply Kubernetes resources with namespace awareness
apply_resource() {
    local file="$1"
    local namespace="$2"
    kubectl apply -f "$file" -n "$namespace"
    echo "Applied $file in namespace $namespace"
}

# Create namespaces if they don't exist
for ns in grafana monitoring; do
    if ! namespace_exists "$ns"; then
        kubectl create namespace "$ns"
        echo "Created namespace: $ns"
    else
        echo "Namespace $ns already exists"
    fi
done

echo "Installing monitoring stack..."

apply_resource grafana-deploy.yaml grafana
apply_resource grafana-ingress.yaml grafana

apply_resource prometheus-deploy.yaml monitoring
apply_resource prometheus-ingress.yaml monitoring
apply_resource prometheus-service.yaml monitoring

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade node-exporter prometheus-community/prometheus-node-exporter \
    --namespace monitoring \
    --set service.type=ClusterIP \
    --set service.name=node-exporter \
    --set fullnameOverride=node-exporter \
    --set daemonset.enabled=true

apply_resource prometheus-configmap.yaml monitoring

echo "Monitoring stack installation complete!"

echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n grafana
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring

echo "Monitoring stack is ready!"