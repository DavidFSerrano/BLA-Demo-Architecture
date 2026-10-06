#!/usr/bin/env bash
# Run this against bla-demo-prod before `terraform destroy` in Terraform/environments/Prod.
# It does not run destroy itself.
set -euo pipefail

REGION=us-east-2
CLUSTER=bla-demo-prod
WRITER=bla-demo-prod-booking

echo "Deleting the Argo CD apps that own Ingresses so they are not recreated..."
kubectl delete application booking booking-prod booking-dev argocd-ingress -n argocd --wait=true --ignore-not-found

echo "Deleting any Ingresses still in the cluster..."
kubectl delete ingress --all -A --wait=true --ignore-not-found

VPC_ID=$(aws eks describe-cluster --region "$REGION" --name "$CLUSTER" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "Waiting for load balancers in $VPC_ID to disappear..."
while true; do
  COUNT=$(aws elbv2 describe-load-balancers --region "$REGION" --query "length(LoadBalancers[?VpcId=='$VPC_ID'])" --output text)
  if [[ "$COUNT" == "0" ]]; then
    break
  fi
  echo "  $COUNT load balancer(s) still deleting..."
  sleep 15
done

echo "Turning off deletion protection on $WRITER..."
aws rds modify-db-instance \
  --region "$REGION" \
  --db-instance-identifier "$WRITER" \
  --no-deletion-protection \
  --apply-immediately \
  --output text >/dev/null

echo "Waiting until $WRITER is available with deletion protection off..."
while true; do
  read -r STATUS PROTECT < <(aws rds describe-db-instances \
    --region "$REGION" \
    --db-instance-identifier "$WRITER" \
    --query 'DBInstances[0].[DBInstanceStatus,DeletionProtection]' \
    --output text)
  if [[ "$STATUS" == "available" && "$PROTECT" == "False" ]]; then
    break
  fi
  echo "  status=$STATUS deletion_protection=$PROTECT"
  sleep 15
done

echo "Ready. From Terraform/environments/Prod run: terraform destroy"
