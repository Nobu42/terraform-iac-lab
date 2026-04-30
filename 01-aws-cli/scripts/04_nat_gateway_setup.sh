#!/bin/bash
set -euo pipefail

PROFILE="learning"
REGION="ap-northeast-1"
PUBLIC_SUBNET_01_NAME="sample-subnet-public01"
PUBLIC_SUBNET_02_NAME="sample-subnet-public02"

# LocalStack向け設定が残っていても実AWSへ向ける
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

echo "=== Caller Identity ==="
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get Public Subnet IDs ==="
PUB01_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$PUBLIC_SUBNET_01_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)

PUB02_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$PUBLIC_SUBNET_02_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)

if [ "$PUB01_ID" = "None" ] || [ -z "$PUB01_ID" ]; then
  echo "Error: Public subnet 01 not found. Please run 02_subnet_setup.sh first."
  exit 1
fi

if [ "$PUB02_ID" = "None" ] || [ -z "$PUB02_ID" ]; then
  echo "Error: Public subnet 02 not found. Please run 02_subnet_setup.sh first."
  exit 1
fi

echo "Public Subnet 01: $PUB01_ID"
echo "Public Subnet 02: $PUB02_ID"

echo "=== Allocate Elastic IP for NAT Gateway 01 ==="
ALLOC_ID_01=$(aws ec2 allocate-address \
  --profile "$PROFILE" \
  --region "$REGION" \
  --domain vpc \
  --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=sample-eip-ngw-01},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]' \
  --query 'AllocationId' \
  --output text)

echo "Elastic IP Allocation ID 01: $ALLOC_ID_01"

echo "=== Create NAT Gateway 01 ==="
NGW01_ID=$(aws ec2 create-nat-gateway \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-id "$PUB01_ID" \
  --allocation-id "$ALLOC_ID_01" \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=sample-ngw-01},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]' \
  --query 'NatGateway.NatGatewayId' \
  --output text)

echo "NAT Gateway 01: $NGW01_ID"

echo "=== Allocate Elastic IP for NAT Gateway 02 ==="
ALLOC_ID_02=$(aws ec2 allocate-address \
  --profile "$PROFILE" \
  --region "$REGION" \
  --domain vpc \
  --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=sample-eip-ngw-02},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]' \
  --query 'AllocationId' \
  --output text)

echo "Elastic IP Allocation ID 02: $ALLOC_ID_02"

echo "=== Create NAT Gateway 02 ==="
NGW02_ID=$(aws ec2 create-nat-gateway \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-id "$PUB02_ID" \
  --allocation-id "$ALLOC_ID_02" \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=sample-ngw-02},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]' \
  --query 'NatGateway.NatGatewayId' \
  --output text)

echo "NAT Gateway 02: $NGW02_ID"

echo "=== Wait for NAT Gateways to become available ==="
aws ec2 wait nat-gateway-available \
  --profile "$PROFILE" \
  --region "$REGION" \
  --nat-gateway-ids "$NGW01_ID" "$NGW02_ID"

echo "NAT Gateways are available."

echo "=== Describe NAT Gateways ==="
aws ec2 describe-nat-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --nat-gateway-ids "$NGW01_ID" "$NGW02_ID" \
  --query 'NatGateways[*].{Name:Tags[?Key==`Name`].Value|[0],ID:NatGatewayId,State:State,Subnet:SubnetId,PublicIP:NatGatewayAddresses[0].PublicIp,AllocationId:NatGatewayAddresses[0].AllocationId}' \
  --output table

