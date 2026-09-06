#!/usr/bin/env bash

set -euo pipefail

AWS_REGION="eu-west-2"
CLUSTER_NAME="eks-project"
TF_DIR="terraform/environments/prod"

echo "========================================"
echo "Preparing cluster for Terraform destroy"
echo "========================================"

echo "Updating kubeconfig..."
aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME"

echo "Deleting Argo CD application..."
kubectl delete application eks-2048 \
  -n argocd \
  --ignore-not-found=true || true

echo "Deleting application ingress..."
kubectl delete ingress \
  -l app=eks-2048 \
  --ignore-not-found=true || true

echo "Removing ExternalDNS..."
helm uninstall external-dns \
  -n external-dns \
  --ignore-not-found || true

echo "Removing NGINX Ingress Controller..."
helm uninstall ingress-nginx \
  -n ingress-nginx \
  --ignore-not-found || true

echo "Waiting for Kubernetes LoadBalancer services to disappear..."

for i in {1..60}; do
  LB_COUNT=$(kubectl get svc -A \
    --field-selector spec.type=LoadBalancer \
    --no-headers 2>/dev/null | wc -l)

  if [ "$LB_COUNT" -eq 0 ]; then
    echo "No Kubernetes LoadBalancer services remain."
    break
  fi

  echo "Still waiting for $LB_COUNT LoadBalancer service(s)..."
  sleep 10
done

echo "Checking for remaining LoadBalancer services..."
kubectl get svc -A \
  --field-selector spec.type=LoadBalancer || true

echo "========================================"
echo "Kubernetes cleanup complete"
echo "========================================"

echo
echo "Terraform is NOT being destroyed automatically."
echo "Review the output above first."
echo
echo "When ready, run:"
echo "cd $TF_DIR"
echo "terraform destroy"
