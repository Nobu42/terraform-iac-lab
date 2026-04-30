#!/bin/bash
set -euo pipefail

PROFILE="learning"
REGION="ap-northeast-1"
VPC_NAME="sample-vpc"

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

echo "=== Create Public Subnet 01 ==="
PUB01_ID=$(aws ec2 create-subnet \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.0.0/20 \
  --availability-zone ap-northeast-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sample-subnet-public01},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning},{Key=Type,Value=public}]' \
  --query 'Subnet.SubnetId' \
  --output text)

aws ec2 modify-subnet-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-id "$PUB01_ID" \
  --map-public-ip-on-launch

echo "=== Create Public Subnet 02 ==="
PUB02_ID=$(aws ec2 create-subnet \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.16.0/20 \
  --availability-zone ap-northeast-1c \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sample-subnet-public02},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning},{Key=Type,Value=public}]' \
  --query 'Subnet.SubnetId' \
  --output text)

aws ec2 modify-subnet-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --subnet-id "$PUB02_ID" \
  --map-public-ip-on-launch

echo "=== Create Private Subnet 01 ==="
PRI01_ID=$(aws ec2 create-subnet \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.64.0/20 \
  --availability-zone ap-northeast-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sample-subnet-private01},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning},{Key=Type,Value=private}]' \
  --query 'Subnet.SubnetId' \
  --output text)

echo "=== Create Private Subnet 02 ==="
PRI02_ID=$(aws ec2 create-subnet \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.80.0/20 \
  --availability-zone ap-northeast-1c \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sample-subnet-private02},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning},{Key=Type,Value=private}]' \
  --query 'Subnet.SubnetId' \
  --output text)

echo "Subnets created:"
echo "  Public : $PUB01_ID, $PUB02_ID"
echo "  Private: $PRI01_ID, $PRI02_ID"

echo "=== Describe Subnets ==="
aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value|[0],Type:Tags[?Key==`Type`].Value|[0],AZ:AvailabilityZone,CIDR:CidrBlock,PublicIP:MapPublicIpOnLaunch,ID:SubnetId}' \
  --output table

