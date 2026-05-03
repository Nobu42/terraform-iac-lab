#!/bin/bash
set -euo pipefail

PROFILE="learning"
REGION="ap-northeast-1"

unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

echo "=== NAT Gateways ==="
aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'NatGateways[*].{ID:NatGatewayId,State:State,VpcId:VpcId,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

echo "=== Elastic IPs ==="
aws ec2 describe-addresses \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Addresses[*].{AllocationId:AllocationId,PublicIp:PublicIp,AssociationId:AssociationId,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

echo "=== Load Balancers ==="
aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'LoadBalancers[*].{Name:LoadBalancerName,State:State.Code,DNS:DNSName}' \
  --output table

echo "=== RDS Instances ==="
aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Class:DBInstanceClass,Public:PubliclyAccessible}' \
  --output table

echo "=== S3 Buckets ==="
aws s3 ls \
  --profile "$PROFILE"

