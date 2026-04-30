#!/bin/bash
set -euo pipefail

PROFILE="learning"
REGION="ap-northeast-1"
VPC_NAME="sample-vpc"
VPC_CIDR="10.0.0.0/16"

# LocalStack向けの設定が残っていても実AWSへ向ける
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

echo "=== Caller Identity ==="
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Create VPC ==="
VPC_ID=$(aws ec2 create-vpc \
  --profile "$PROFILE" \
  --region "$REGION" \
  --cidr-block "$VPC_CIDR" \
  --instance-tenancy default \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
  --query 'Vpc.VpcId' \
  --output text)

echo "New VPC ID: $VPC_ID"

aws ec2 modify-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames '{"Value":true}'

aws ec2 modify-vpc-attribute \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --enable-dns-support '{"Value":true}'

aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --vpc-ids "$VPC_ID" \
  --query 'Vpcs[*].{ID:VpcId,Name:Tags[?Key==`Name`].Value|[0],CIDR:CidrBlock,State:State,DNSHost:EnableDnsHostnames.Value,DNSSupport:EnableDnsSupport.Value}' \
  --output table

