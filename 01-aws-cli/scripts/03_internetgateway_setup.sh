#!/bin/bash
set -euo pipefail

PROFILE="learning"
REGION="ap-northeast-1"
VPC_NAME="sample-vpc"
IGW_NAME="sample-igw"

# LocalStack向け設定が残っていても実AWSへ向ける
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

echo "=== Caller Identity ==="
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get VPC ID ==="
VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "Error: VPC not found. Please run 01_vpc_setup.sh first."
  exit 1
fi

echo "Target VPC ID: $VPC_ID"

echo "=== Create Internet Gateway ==="
IGW_ID=$(aws ec2 create-internet-gateway \
  --profile "$PROFILE" \
  --region "$REGION" \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$IGW_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

echo "Created IGW ID: $IGW_ID"

echo "=== Attach Internet Gateway to VPC ==="
aws ec2 attach-internet-gateway \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --internet-gateway-id "$IGW_ID"

echo "Success! Attached IGW ($IGW_ID) to VPC ($VPC_ID)"

echo "=== Describe Internet Gateway ==="
aws ec2 describe-internet-gateways \
  --profile "$PROFILE" \
  --region "$REGION" \
  --internet-gateway-ids "$IGW_ID" \
  --query 'InternetGateways[*].{ID:InternetGatewayId,Name:Tags[?Key==`Name`].Value|[0],VPC:Attachments[0].VpcId,State:Attachments[0].State}' \
  --output table

