#!/bin/bash
set -euo pipefail

PROFILE="learning"
REGION="ap-northeast-1"

VPC_NAME="sample-vpc"
PUBLIC_SUBNET_NAME="sample-subnet-public01"
BASTION_SG_NAME="sample-sg-bastion"

KEY_NAME="nobu"
KEY_FILE="${KEY_NAME}.pem"
INSTANCE_NAME="sample-ec2-bastion"
INSTANCE_TYPE="t3.micro"

# LocalStack向け設定が残っていても実AWSへ向ける
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

# Amazon Linux 2023 latest AMI
AMI_ID=$(aws ssm get-parameter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' \
  --output text)

get_required_id() {
  local label="$1"
  local value="$2"

  if [ "$value" = "None" ] || [ -z "$value" ]; then
    echo "Error: $label not found. Please check previous setup scripts."
    exit 1
  fi

  echo "$value"
}

echo "=== Caller Identity ==="
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get Resource IDs ==="
VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text)
VPC_ID=$(get_required_id "VPC" "$VPC_ID")

PUB01_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$PUBLIC_SUBNET_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)
PUB01_ID=$(get_required_id "Public Subnet 01" "$PUB01_ID")

SG_BASTION_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$BASTION_SG_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)
SG_BASTION_ID=$(get_required_id "Bastion Security Group" "$SG_BASTION_ID")

echo "VPC: $VPC_ID"
echo "Public Subnet: $PUB01_ID"
echo "Bastion Security Group: $SG_BASTION_ID"
echo "AMI: $AMI_ID"

echo "=== Recreate Key Pair ==="
aws ec2 delete-key-pair \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-name "$KEY_NAME" >/dev/null 2>&1 || true

rm -f "$KEY_FILE"

aws ec2 create-key-pair \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-name "$KEY_NAME" \
  --tag-specifications "ResourceType=key-pair,Tags=[{Key=Name,Value=$KEY_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
  --query 'KeyMaterial' \
  --output text > "$KEY_FILE"

chmod 400 "$KEY_FILE"

echo "Key pair created: $KEY_NAME"
echo "Private key saved: $KEY_FILE"

echo "=== Launch Bastion Instance ==="
BASTION_ID=$(aws ec2 run-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_BASTION_ID" \
  --subnet-id "$PUB01_ID" \
  --associate-public-ip-address \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Waiting for Bastion ($BASTION_ID) to be running..."
aws ec2 wait instance-running \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$BASTION_ID"

PUBLIC_IP=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$BASTION_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

PRIVATE_IP=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$BASTION_ID" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

echo "Bastion is running."
echo "Instance ID: $BASTION_ID"
echo "Public IP: $PUBLIC_IP"
echo "Private IP: $PRIVATE_IP"

echo "=== SSH Command ==="
echo "ssh -i $KEY_FILE ec2-user@$PUBLIC_IP"

echo "=== Describe Bastion Instance ==="
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$BASTION_ID" \
  --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name,Type:InstanceType,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,Subnet:SubnetId}' \
  --output table
