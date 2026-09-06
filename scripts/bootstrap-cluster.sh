#!/usr/bin/env bash

set -euo pipefail

AWS_REGION="eu-west-2"
CLUSTER_NAME="eks-project"

echo "========================================"
echo "Bootstrapping EKS cluster"
echo "========================================"

echo "Updating kubeconfig..."
aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME"

echo "Waiting for EKS nodes..."
kubectl wait \
  --for=condition=Ready \
  nodes \
  --all \
  --timeout=600s

echo "Adding Helm repositories..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
helm repo add jetstack https://charts.jetstack.io || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/ || true

helm repo update

echo "Installing NGINX Ingress Controller..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --wait \
  --timeout 10m

echo "Installing CertManager..."
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --wait \
  --timeout 10m

echo "Creating production ClusterIssuer..."
kubectl apply -f k8s/clusterissuer-production.yaml

echo "Installing Metrics Server..."
kubectl apply -f \
  https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo "Installing Prometheus and Grafana..."
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --wait \
  --timeout 15m

echo "Installing ExternalDNS..."

kubectl create namespace external-dns \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl create serviceaccount external-dns \
  --namespace external-dns \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl annotate serviceaccount external-dns \
  --namespace external-dns \
  eks.amazonaws.com/role-arn=arn:aws:iam::583931059504:role/eks-project-external-dns-role \
  --overwrite

helm upgrade --install external-dns external-dns/external-dns \
  --namespace external-dns \
  --set serviceAccount.create=false \
  --set serviceAccount.name=external-dns \
  --set provider.name=aws \
  --set policy=upsert-only \
  --set registry=txt \
  --set txtOwnerId=eks-project \
  --set domainFilters[0]=abdimajidcloud.com \
  --wait \
  --timeout 10m

echo "Installing Argo CD..."

kubectl create namespace argocd \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl apply \
  --server-side \
  --force-conflicts \
  -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD..."
kubectl wait \
  --for=condition=Available \
  deployment/argocd-server \
  -n argocd \
  --timeout=300s

echo "Creating Argo CD application..."
cat <<'APP' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: eks-2048
  namespace: argocd

spec:
  project: default

  source:
    repoURL: https://github.com/AbdimajidHussein03/eks-project.git
    targetRevision: main
    path: helm/eks-2048

  destination:
    server: https://kubernetes.default.svc
    namespace: default

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
APP

echo "========================================"
echo "Bootstrap complete"
echo "========================================"

echo
echo "Nodes:"
kubectl get nodes

echo
echo "NGINX:"
kubectl get pods -n ingress-nginx

echo
echo "CertManager:"
kubectl get pods -n cert-manager

echo
echo "ExternalDNS:"
kubectl get pods -n external-dns

echo
echo "Monitoring:"
kubectl get pods -n monitoring

echo
echo "Argo CD:"
kubectl get pods -n argocd

echo
echo "Argo Application:"
kubectl get application -n argocd

echo
echo "2048:"
kubectl get pods -l app=eks-2048

echo
echo "Certificate:"
kubectl get certificate

echo
echo "Ingress:"
kubectl get ingress
