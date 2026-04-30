#!/bin/bash
set -euo pipefail

PROFILE="learning"
REGION="ap-northeast-1"
VPC_NAME="sample-vpc"

BASTION_SG_NAME="sample-sg-bastion"
ELB_SG_NAME="sample-sg-elb"

MY_GLOBAL_IP=$(curl -s https://checkip.amazonaws.com | tr -d '\n')

if [ -z "$MY_GLOBAL_IP" ]; then
  echo "Error: Could not detect global IP address."
  exit 1
fi

SSH_ALLOWED_CIDR="${MY_GLOBAL_IP}/32"
HTTP_ALLOWED_CIDR="0.0.0.0/0"
HTTPS_ALLOWED_CIDR="0.0.0.0/0"

echo "SSH allowed CIDR: $SSH_ALLOWED_CIDR"


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

echo "=== Create Bastion Security Group ==="
SG_BASTION_ID=$(aws ec2 create-security-group \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-name "$BASTION_SG_NAME" \
  --description "for bastion server" \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$BASTION_SG_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id "$SG_BASTION_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$SSH_ALLOWED_CIDR,Description='SSH access for learning'}]"

echo "Bastion Security Group: $SG_BASTION_ID"

echo "=== Create ELB Security Group ==="
SG_ELB_ID=$(aws ec2 create-security-group \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-name "$ELB_SG_NAME" \
  --description "for load balancer" \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$ELB_SG_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id "$SG_ELB_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=$HTTP_ALLOWED_CIDR,Description='HTTP access'}]"

aws ec2 authorize-security-group-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id "$SG_ELB_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=$HTTPS_ALLOWED_CIDR,Description='HTTPS access'}]"

echo "ELB Security Group: $SG_ELB_ID"

echo "Security Groups created: Bastion($SG_BASTION_ID), ELB($SG_ELB_ID)"

echo "=== Describe Security Groups ==="
aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-ids "$SG_BASTION_ID" "$SG_ELB_ID" \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,Description:Description,Rules:IpPermissions[*].{Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,Cidr:IpRanges[0].CidrIp,RuleDescription:IpRanges[0].Description}}' \
  --output table

