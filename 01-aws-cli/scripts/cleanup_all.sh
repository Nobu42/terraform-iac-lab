#!/bin/bash
set -euo pipefail

PROFILE="learning"
REGION="ap-northeast-1"

VPC_NAME="sample-vpc"
KEY_NAME="nobu"
KEY_FILE="nobu.pem"

unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

echo "=== Caller Identity ==="
aws sts get-caller-identity --profile "$PROFILE" --output table

echo "=== Get VPC ID ==="
VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "VPC not found. Nothing to delete."
  exit 0
fi

echo "Target VPC: $VPC_ID"

echo "=== Terminate EC2 Instances ==="
INSTANCE_IDS=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters \
    Name=vpc-id,Values="$VPC_ID" \
    Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)

if [ -n "$INSTANCE_IDS" ]; then
  echo "Terminating: $INSTANCE_IDS"
  aws ec2 terminate-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --instance-ids $INSTANCE_IDS >/dev/null

  aws ec2 wait instance-terminated \
    --profile "$PROFILE" \
    --region "$REGION" \
    --instance-ids $INSTANCE_IDS
else
  echo "No EC2 instances found."
fi

echo "=== Delete custom Security Groups ==="
for sg_name in sample-sg-web sample-sg-bastion sample-sg-elb; do
  SG_ID=$(aws ec2 describe-security-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$sg_name" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true)

  if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
    echo "Deleting SG: $sg_name ($SG_ID)"
    aws ec2 delete-security-group \
      --profile "$PROFILE" \
      --region "$REGION" \
      --group-id "$SG_ID" || echo "Skip: could not delete $sg_name yet"
  fi
done

echo "=== Delete custom Route Tables ==="
RT_IDS=$(aws ec2 describe-route-tables \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'RouteTables[?Tags[?Key==`Name` && (Value==`sample-rt-public` || Value==`sample-rt-private01` || Value==`sample-rt-private02`)]].RouteTableId' \
  --output text)

for rt_id in $RT_IDS; do
  ASSOC_IDS=$(aws ec2 describe-route-tables \
    --profile "$PROFILE" \
    --region "$REGION" \
    --route-table-ids "$rt_id" \
    --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' \
    --output text)

  for assoc_id in $ASSOC_IDS; do
    echo "Disassociating route table association: $assoc_id"
    aws ec2 disassociate-route-table \
      --profile "$PROFILE" \
      --region "$REGION" \
      --association-id "$assoc_id"
  done

  echo "Deleting route table: $rt_id"
  aws ec2 delete-route-table \
    --profile "$PROFILE" \
    --region "$REGION" \
    --route-table-id "$rt_id"
done

echo "=== Collect Elastic IP Allocation IDs ==="
ALLOC_IDS=$(aws ec2 describe-addresses \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values=sample-eip-ngw-01,sample-eip-ngw-02 \
  --query 'Addresses[].AllocationId' \
  --output text)

echo "=== Delete NAT Gateways ==="
NAT_IDS=$(aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filter Name=vpc-id,Values="$VPC_ID" Name=state,Values=pending,available \
  --query 'NatGateways[].NatGatewayId' \
  --output text)

if [ -n "$NAT_IDS" ]; then
  for nat_id in $NAT_IDS; do
    echo "Deleting NAT Gateway: $nat_id"
    aws ec2 delete-nat-gateway \
      --profile "$PROFILE" \
      --region "$REGION" \
      --nat-gateway-id "$nat_id" >/dev/null
  done

  echo "Waiting for NAT Gateways to be deleted..."
  aws ec2 wait nat-gateway-deleted \
    --profile "$PROFILE" \
    --region "$REGION" \
    --nat-gateway-ids $NAT_IDS
else
  echo "No NAT Gateways found."
fi

echo "=== Release Elastic IPs ==="
for alloc_id in $ALLOC_IDS; do
  echo "Releasing EIP: $alloc_id"
  aws ec2 release-address \
    --profile "$PROFILE" \
    --region "$REGION" \
    --allocation-id "$alloc_id" || echo "Skip: could not release $alloc_id"
done

echo "=== Detach and Delete Internet Gateway ==="
IGW_ID=$(aws ec2 describe-internet-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=attachment.vpc-id,Values="$VPC_ID" \
  --query 'InternetGateways[0].InternetGatewayId' \
  --output text)

if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
  echo "Detaching IGW: $IGW_ID"
  aws ec2 detach-internet-gateway \
    --profile "$PROFILE" \
    --region "$REGION" \
    --internet-gateway-id "$IGW_ID" \
    --vpc-id "$VPC_ID"

  echo "Deleting IGW: $IGW_ID"
  aws ec2 delete-internet-gateway \
    --profile "$PROFILE" \
    --region "$REGION" \
    --internet-gateway-id "$IGW_ID"
fi

echo "=== Delete Subnets ==="
SUBNET_IDS=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'Subnets[].SubnetId' \
  --output text)

for subnet_id in $SUBNET_IDS; do
  echo "Deleting subnet: $subnet_id"
  aws ec2 delete-subnet \
    --profile "$PROFILE" \
    --region "$REGION" \
    --subnet-id "$subnet_id"
done

echo "=== Delete Key Pair ==="
aws ec2 delete-key-pair \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-name "$KEY_NAME" >/dev/null 2>&1 || true

rm -f "$KEY_FILE"

echo "=== Delete VPC ==="
aws ec2 delete-vpc \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID"

echo "=== Cleanup completed ==="

