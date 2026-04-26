#!/bin/bash

# 0. ID取得
PUB01_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public01 --query 'Subnets[0].SubnetId' --output text)
PUB02_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public02 --query 'Subnets[0].SubnetId' --output text)

# --- NAT Gateway 01 ---
ALLOC_ID_01=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)

NGW01_ID=$(aws ec2 create-nat-gateway \
    --subnet-id $PUB01_ID \
    --allocation-id $ALLOC_ID_01 \
    --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=sample-ngw-01}]' \
    --query 'NatGateway.NatGatewayId' --output text)

# --- NAT Gateway 02 ---
ALLOC_ID_02=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)

NGW02_ID=$(aws ec2 create-nat-gateway \
    --subnet-id $PUB02_ID \
    --allocation-id $ALLOC_ID_02 \
    --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=sample-ngw-02}]' \
    --query 'NatGateway.NatGatewayId' --output text)

echo "Waiting for NAT Gateways to become available..."
# 本番環境ではこれがないと次のルート設定で失敗することがあります
aws ec2 wait nat-gateway-available --nat-gateway-ids $NGW01_ID $NGW02_ID

echo "NAT Gateways are READY: $NGW01_ID, $NGW02_ID"

# 確認表示
aws ec2 describe-nat-gateways \
    --query 'NatGateways[*].{Name:Tags[?Key==`Name`].Value | [0], State:State, PublicIP:NatGatewayAddresses[0].PublicIp}' \
    --output table
