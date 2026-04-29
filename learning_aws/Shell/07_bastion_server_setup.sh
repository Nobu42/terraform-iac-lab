#!/bin/bash

# --- 0. 必要なIDを再取得 ---
VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=sample-vpc --query 'Vpcs[0].VpcId' --output text)
PUB01_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public01 --query 'Subnets[0].SubnetId' --output text)
SG_BASTION_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=sample-sg-bastion --query 'SecurityGroups[0].GroupId' --output text)

# --- 1. キーペアの再作成 ---
aws ec2 delete-key-pair --key-name nobu > /dev/null 2>&1
rm -f nobu.pem
aws ec2 create-key-pair --key-name nobu --query 'KeyMaterial' --output text > nobu.pem
chmod 400 nobu.pem

# --- 2. 踏み台サーバー（Bastion）の起動 ---
# AMI ID: ami-07b643b5e45e (LocalStack用 AL2)
BASTION_ID=$(aws ec2 run-instances \
    --image-id ami-07b643b5e45e \
    --count 1 \
    --instance-type t2.micro \
    --key-name nobu \
    --security-group-ids $SG_BASTION_ID \
    --subnet-id $PUB01_ID \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sample-ec2-bastion}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Waiting for Bastion ($BASTION_ID) to be running..."
aws ec2 wait instance-running --instance-ids $BASTION_ID

# 起動直後のIPと、SSHポート転送設定の確認
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $BASTION_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "Bastion is ready at $PUBLIC_IP"
echo "Check your docker ps for the SSH port mapping (e.g., 60577)."
