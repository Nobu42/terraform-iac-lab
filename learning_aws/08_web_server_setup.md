#!/bin/bash

# --- 設定項目 ---
UBUNTU_IP="192.168.40.100"
ENDPOINT="http://${UBUNTU_IP}:4566"
REGION="ap-northeast-1"

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=$REGION

echo "--------------------------------------------------"
echo "🚀 Starting Web Servers Setup (Final Fix)"
echo "--------------------------------------------------"

# --- 0. AMI IDの取得 ---
AMI_ID=$(aws --endpoint-url=$ENDPOINT ec2 describe-images \
    --owners self \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text)
echo "✅ Using AMI ID: $AMI_ID"

# --- 1. ネットワークリソースのID取得 ---
PRI01_ID=$(aws --endpoint-url=$ENDPOINT ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-private01 --query 'Subnets[0].SubnetId' --output text)
PRI02_ID=$(aws --endpoint-url=$ENDPOINT ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-private02 --query 'Subnets[0].SubnetId' --output text)
SG_WEB_ID=$(aws --endpoint-url=$ENDPOINT ec2 describe-security-groups --filters Name=group-name,Values=sample-sg-web --query 'SecurityGroups[0].GroupId' --output text)

# --- 2. Webサーバーの起動 (タイポ修正済み) ---
echo "3. Launching Web instances..."

# Web01 (失敗していた場合のために再送)
WEB01_ID=$(aws --endpoint-url=$ENDPOINT ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type t2.micro \
    --key-name nobu \
    --security-group-ids $SG_WEB_ID \
    --subnet-id $PRI01_ID \
    --no-associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sample-ec2-web01}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

# Web02 (ここが通っていませんでした)
WEB02_ID=$(aws --endpoint-url=$ENDPOINT ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type t2.micro \
    --key-name nobu \
    --security-group-ids $SG_WEB_ID \
    --subnet-id $PRI02_ID \
    --no-associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sample-ec2-web02}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "✅ Created Web01: $WEB01_ID"
echo "✅ Created Web02: $WEB02_ID"

# --- 3. 待機 ---
BASTION_ID=$(aws --endpoint-url=$ENDPOINT ec2 describe-instances --filters "Name=tag:Name,Values=sample-ec2-bastion" --query 'Reservations[].Instances[].InstanceId' --output text)
echo "⏳ Waiting for running state..."
aws --endpoint-url=$ENDPOINT ec2 wait instance-running --instance-ids $BASTION_ID $WEB01_ID $WEB02_ID

# --- 4. setup_user.sh の実行 (コンテナ名解決) ---
# Ubuntu側の setup_user.sh がコンテナを探せるように工夫
echo "4. Running setup_user.sh on Ubuntu..."
for id in $BASTION_ID $WEB01_ID $WEB02_ID; do
    echo "⚙️ Processing $id..."
    # コンテナ名が localstack-ec2.ID ではなく ID そのものの場合があるため
    ssh nobu@${UBUNTU_IP} "bash ~/setup_user.sh $id || docker exec $id bash -c 'useradd -m ec2-user && mkdir -p /home/ec2-user/.ssh && chown ec2-user:ec2-user /home/ec2-user/.ssh'"
done

# --- 5. SSH Config更新 ---
NEW_PORT=$(ssh nobu@${UBUNTU_IP} "docker ps" | grep "$BASTION_ID" | sed -E 's/.*:([0-9]+)->22.*/\1/')
if [ -n "$NEW_PORT" ]; then
    sed -i '' -e "/Host bastion/,/Port/ s/Port [0-9]*/Port $NEW_PORT/" ~/.ssh/config
    echo "✅ SSH Config updated: Port $NEW_PORT"
fi

# --- 6. 最終確認 ---
echo "--------------------------------------------------"
aws --endpoint-url=$ENDPOINT ec2 describe-instances \
    --instance-ids $BASTION_ID $WEB01_ID $WEB02_ID \
    --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value | [0], ID:InstanceId, PrivateIP:PrivateIpAddress}' \
    --output table
