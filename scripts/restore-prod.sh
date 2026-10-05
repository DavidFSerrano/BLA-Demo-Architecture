#!/usr/bin/env bash
# Recreate bla-demo-prod after a destroy: Terraform, then Argo CD and the apps.
# Applies the current checkout without prompting.
set -euo pipefail

REGION=us-east-2
CLUSTER=bla-demo-prod
ARGOCD_VERSION=v3.5.3

ROOT=$(cd "$(dirname "$0")/.." && pwd)

echo "Applying Terraform in environments/Prod..."
terraform -chdir="$ROOT/Terraform/environments/Prod" init -input=false
terraform -chdir="$ROOT/Terraform/environments/Prod" apply -input=false -auto-approve

echo "Pointing kubectl at $CLUSTER..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER" >/dev/null

echo "Waiting for worker nodes..."
kubectl wait --for=condition=Ready nodes --all --timeout=20m

echo "Installing Argo CD $ARGOCD_VERSION..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
kubectl apply -f "$ROOT/argo/platform/argocd-cmd-params.yaml"
kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout status deployment/argocd-server -n argocd --timeout=10m

echo "Installing the platform and booking apps..."
kubectl apply -f "$ROOT/argo/helm-applicationset.yaml"
kubectl apply -f "$ROOT/argo/booking.yaml"
kubectl apply -f "$ROOT/argo/argocd-ingress.yaml"

echo "Prod is up. Argo CD will sync the Helm charts and the booking app from main."
