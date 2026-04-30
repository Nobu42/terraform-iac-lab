#!/bin/bash

# --- 1. 必要な ID を再取得 ---
VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=sample-vpc --query 'Vpcs[0].VpcId' --output text)
PUB01_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public01 --query 'Subnets[0].SubnetId' --output text)
PUB02_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public02 --query 'Subnets[0].SubnetId' --output text)

# ここで None になるのを防ぐため、IDが見つかるまで数秒待つか、エラー終了させる
WEB01_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=sample-ec2-web01 --query 'Reservations[0].Instances[0].InstanceId' --output text)
WEB02_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=sample-ec2-web02 --query 'Reservations[0].Instances[0].InstanceId' --output text)

if [ "$WEB01_ID" == "None" ] || [ -z "$WEB01_ID" ]; then
    echo "Error: Web01 ID not found. Check if 08_Web_server_setup.sh succeeded."
    exit 1
fi

# --- 2. ターゲットグループを作成 ---
TG_ARN=$(aws elbv2 create-target-group \
    --name sample-tg \
    --protocol HTTP \
    --port 3000 \
    --vpc-id $VPC_ID \
    --health-check-protocol HTTP \
    --health-check-path / \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo " Target Group Created: $TG_ARN"

# --- 3. Webサーバーを登録 ---
aws elbv2 register-targets \
    --target-group-arn $TG_ARN \
    --targets Id=$WEB01_ID Id=$WEB02_ID

echo " Web01 and Web02 registered to Target Group."

# --- 4. LB用セキュリティグループの ID を取得 ---
SG_ELB_ID=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=sample-sg-elb \
    --query 'SecurityGroups[0].GroupId' --output text)

# --- 5. ロードバランサー（ALB）本体の作成 ---
LB_ARN=$(aws elbv2 create-load-balancer \
    --name sample-elb \
    --subnets $PUB01_ID $PUB02_ID \
    --security-groups $SG_ELB_ID \
    --scheme internet-facing \
    --type application \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

echo " Load Balancer Created: $LB_ARN"

# --- 6. リスナーの作成 ---
echo "Creating Listener (Port 80)..."
aws elbv2 create-listener \
    --load-balancer-arn $LB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN

# --- 7. セキュリティグループの適用 (書籍の設計通り default SG を利用) ---

# Web01 が今着ている SG ID を取得
SG_CURRENT_ID=$(aws ec2 describe-instances \
    --instance-ids $WEB01_ID \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text)

# もし LocalStack のメタデータ反映遅延で None が返った場合のセーフティネット
if [ "$SG_CURRENT_ID" == "None" ] || [ -z "$SG_CURRENT_ID" ]; then
    echo " Warning: Instance SG not found via describe-instances. Fetching VPC default SG..."
    SG_CURRENT_ID=$(aws ec2 describe-security-groups \
        --filters Name=vpc-id,Values=$VPC_ID Name=group-name,Values=default \
        --query 'SecurityGroups[0].GroupId' --output text)
fi

echo " Target Web SG ID: $SG_CURRENT_ID"

# その SG に対して ALB からの通信を許可 (Port 3000)
echo " Allowing traffic from LB SG ($SG_ELB_ID) to Web SG ($SG_CURRENT_ID) on Port 3000..."

aws ec2 authorize-security-group-ingress \
    --group-id $SG_CURRENT_ID \
    --protocol tcp \
    --port 3000 \
    --source-group $SG_ELB_ID 2>/dev/null || echo " Rule already exists or skipped."

# --- 8. 完了表示 ---
echo "------------------------------------------------"
echo " Setup Complete!"
echo "------------------------------------------------"
echo " Access URL:"
echo " http://sample-elb.elb.localhost.localstack.cloud:4566"
echo "------------------------------------------------"
