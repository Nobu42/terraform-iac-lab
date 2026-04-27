#!/bin/bash

# --- 設定項目 ---
# UbuntuサーバーのIPアドレス（Macからの接続先）
UBUNTU_IP="192.168.40.100"
ENDPOINT="http://${UBUNTU_IP}:4566"
REGION="ap-northeast-1"

# AWS CLIの認証情報を環境変数で固定（Macの環境を汚さないようexport）
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=$REGION

echo "--------------------------------------------------"
echo "🚀 Starting Bastion Server Setup (Remote to Ubuntu: $UBUNTU_IP)"
echo "--------------------------------------------------"

# --- 0. カスタムAMIをその場で登録 ---
# ※LocalStack内のDockerイメージ名はUbuntu上のDockerが持っている名前を指定
echo "1. Registering custom AMI from Docker image..."
AMI_ID=$(aws --endpoint-url=$ENDPOINT ec2 register-image \
    --name "custom-yum-ami-$(date +%s)" \
    --description "Amazon Linux 2 with yum (Packer build)" \
    --image-location "localstack-custom-ami:latest" \
    --architecture x86_64 \
    --root-device-name /dev/sda1 \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={SnapshotId=snap-12345}" \
    --virtualization-type hvm \
    --query 'ImageId' --output text)

if [ "$AMI_ID" == "None" ] || [ -z "$AMI_ID" ]; then
    echo "❌ Error: Failed to register AMI. Check if LocalStack is running on $UBUNTU_IP"
    exit 1
fi
echo "✅ Using AMI ID: $AMI_ID"

# --- 1. ネットワークリソースのID取得 ---
echo "2. Fetching network resource IDs..."
VPC_ID=$(aws --endpoint-url=$ENDPOINT ec2 describe-vpcs --filters Name=tag:Name,Values=sample-vpc --query 'Vpcs[0].VpcId' --output text)
PUB01_ID=$(aws --endpoint-url=$ENDPOINT ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public01 --query 'Subnets[0].SubnetId' --output text)
SG_BASTION_ID=$(aws --endpoint-url=$ENDPOINT ec2 describe-security-groups --filters Name=group-name,Values=sample-sg-bastion --query 'SecurityGroups[0].GroupId' --output text)

# --- 2. キーペアの再作成 ---
echo "3. Refreshing EC2 Key Pair..."
aws --endpoint-url=$ENDPOINT ec2 delete-key-pair --key-name nobu > /dev/null 2>&1
rm -f nobu.pem
aws --endpoint-url=$ENDPOINT ec2 create-key-pair --key-name nobu --query 'KeyMaterial' --output text > nobu.pem
chmod 400 nobu.pem

# --- 3. 踏み台サーバー（Bastion）の起動 ---
echo "4. Launching Bastion instance..."
BASTION_ID=$(aws --endpoint-url=$ENDPOINT ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type t2.micro \
    --key-name nobu \
    --security-group-ids $SG_BASTION_ID \
    --subnet-id $PUB01_ID \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sample-ec2-bastion}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

# --- 4. 起動待機 ---
echo "⏳ Waiting for Bastion ($BASTION_ID) to reach 'running' state..."
aws --endpoint-url=$ENDPOINT ec2 wait instance-running --instance-ids $BASTION_ID

# --- 5. 接続情報の出力 ---
PUBLIC_IP=$(aws --endpoint-url=$ENDPOINT ec2 describe-instances --instance-ids $BASTION_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "--------------------------------------------------"
echo "✨ Bastion is ready!"
echo "📍 Remote IP:   $UBUNTU_IP (LocalStack)"
echo "📍 Internal IP: $PUBLIC_IP"
echo "🔑 Key file:    nobu.pem"
echo "--------------------------------------------------"
echo "Next: Try SSH into the bastion."
