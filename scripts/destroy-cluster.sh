#!/usr/bin/env bash

set -euo pipefail

AWS_REGION="eu-west-2"
CLUSTER_NAME="eks-project"
TF_DIR="terraform/environments/prod"

HOSTED_ZONE_ID="Z04928591MJEI8DP2GRRQ"
APP_DOMAIN="eks.abdimajidcloud.com"

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
kubectl delete ingress eks-2048-ingress \
  -n default \
  --ignore-not-found=true || true

echo "Waiting for ExternalDNS to remove Route53 records..."

for i in {1..30}; do
  DNS_COUNT=$(aws route53 list-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --query "length(ResourceRecordSets[?contains(Name, '$APP_DOMAIN')])" \
    --output text)

  if [ "$DNS_COUNT" -eq 0 ]; then
    echo "Application DNS records removed."
    break
  fi

  echo "Still waiting for $DNS_COUNT DNS record(s) to be removed..."
  sleep 10
done

echo "Remaining application DNS records:"
aws route53 list-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --query "ResourceRecordSets[?contains(Name, '$APP_DOMAIN')].[Name,Type]" \
  --output text || true

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
