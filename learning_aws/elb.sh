#!/bin/bash

# ---  必要な ID を再取得して変数に叩き込む ---
VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=sample-vpc --query 'Vpcs[0].VpcId' --output text)
PUB01_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public01 --query 'Subnets[0].SubnetId' --output text)
PUB02_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public02 --query 'Subnets[0].SubnetId' --output text)
WEB01_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=sample-ec2-web01 --query 'Reservations[0].Instances[0].InstanceId' --output text)
WEB02_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=sample-ec2-web02 --query 'Reservations[0].Instances[0].InstanceId' --output text)

# ---  ターゲットグループを作成 ---
TG_ARN=$(aws elbv2 create-target-group \
    --name sample-tg \
    --protocol HTTP \
    --port 3000 \
    --vpc-id $VPC_ID \
    --health-check-protocol HTTP \
    --health-check-path / \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "Target Group ARN: $TG_ARN"

# ---  Webサーバーを登録 ---
aws elbv2 register-targets \
    --target-group-arn $TG_ARN \
    --targets Id=$WEB01_ID Id=$WEB02_ID

# ---  LB用セキュリティグループの ID を取得 ---
SG_ELB_ID=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=sample-sg-elb \
    --query 'SecurityGroups[0].GroupId' --output text)

# ---  ロードバランサー（ALB）本体の作成 ---
LB_ARN=$(aws elbv2 create-load-balancer \
    --name sample-elb \
    --subnets $PUB01_ID $PUB02_ID \
    --security-groups $SG_ELB_ID \
    --scheme internet-facing \
    --type application \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

echo "Load Balancer ARN: $LB_ARN"

#  リスナーの作成（80番ポートの受付開始）
echo "Creating Listener..."
aws elbv2 create-listener \
    --load-balancer-arn $LB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN

#  セキュリティグループの連動（LBからWebサーバーへの3000番を許可）
# ※Webサーバーが使っているSG名を「sample-sg-web」と仮定しています。適宜直してください。
SG_WEB_ID=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=sample-sg-web \
    --query 'SecurityGroups[0].GroupId' --output text)

echo "Allowing traffic from LB SG ($SG_ELB_ID) to Web SG ($SG_WEB_ID) on Port 3000..."
aws ec2 authorize-security-group-ingress \
    --group-id $SG_WEB_ID \
    --protocol tcp \
    --port 3000 \
    --source-group $SG_ELB_ID

#  最後にアクセス用URLを表示
DNS_NAME=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $LB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "------------------------------------------------"
echo "Setup Complete!"
echo "Access URL: http://$DNS_NAME"
echo "------------------------------------------------"
