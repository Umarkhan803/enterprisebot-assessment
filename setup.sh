#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="demo"
NAMESPACE="demo"
RELEASE_NAME="demo"
IMAGE_NAME="server:1.0"
CHART_DIR="./chart"

echo "==> Checking required tools..."

for cmd in docker kind kubectl helm; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: $cmd is not installed or not in PATH."
        exit 1
    fi
done

echo "==> Checking Docker..."

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker is not running."
    exit 1
fi

echo "==> Building application image..."

docker build -t "$IMAGE_NAME" ./service

echo "==> Creating kind cluster if it does not exist..."

if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
cat <<EOF_CLUSTER | kind create cluster \
    --name "$CLUSTER_NAME" \
    --image kindest/node:v1.34.0 \
    --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
EOF_CLUSTER
else
    echo "Kind cluster '$CLUSTER_NAME' already exists."
fi

echo "==> Loading application image into kind..."

kind load docker-image "$IMAGE_NAME" --name "$CLUSTER_NAME"

echo "==> Installing ingress-nginx..."

if ! kubectl get namespace ingress-nginx >/dev/null 2>&1; then
    kubectl apply -f \
      https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.2/deploy/static/provider/kind/deploy.yaml
else
    echo "ingress-nginx namespace already exists."
fi

echo "==> Waiting for ingress-nginx controller..."

kubectl wait \
    --namespace ingress-nginx \
    --for=condition=Ready \
    pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=180s

echo "==> Creating namespace '$NAMESPACE'..."

kubectl create namespace "$NAMESPACE" \
    --dry-run=client \
    -o yaml | kubectl apply -f -

echo "==> Deploying application with Helm..."

helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
    --namespace "$NAMESPACE" \
    --create-namespace

echo "==> Waiting for application rollout..."

kubectl rollout status \
    deployment \
    -n "$NAMESPACE" \
    --timeout=180s

echo
echo "========================================"
echo "Setup completed successfully!"
echo "========================================"
echo
echo "Application:"
echo "  http://demo.local/"
echo
echo "Health:"
echo "  http://demo.local/healthz"
echo
echo "Useful commands:"
echo "  kubectl get pods -n demo"
echo "  kubectl get svc -n demo"
echo "  kubectl get ingress -n demo"
