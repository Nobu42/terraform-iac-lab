#!/bin/bash

# --- 1. 既存のリソース ID / ARN を「探して」変数に入れる ---
VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=sample-vpc --query 'Vpcs[0].VpcId' --output text)
PUB01_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public01 --query 'Subnets[0].SubnetId' --output text)
PUB02_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public02 --query 'Subnets[0].SubnetId' --output text)
WEB01_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=sample-ec2-web01 --query 'Reservations[0].Instances[0].InstanceId' --output text)
SG_ELB_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=sample-sg-elb --query 'SecurityGroups[0].GroupId' --output text)

# ターゲットグループが既にあるか確認、なければ作る
TG_ARN=$(aws elbv2 describe-target-groups --names sample-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)
if [ "$TG_ARN" == "None" ] || [ -z "$TG_ARN" ]; then
    echo "Creating new Target Group..."
    TG_ARN=$(aws elbv2 create-target-group --name sample-tg --protocol HTTP --port 3000 --vpc-id $VPC_ID --query 'TargetGroups[0].TargetGroupArn' --output text)
fi
echo "Target Group ARN: $TG_ARN"

# ロードバランサーが既にあるか確認、なければ作る
LB_ARN=$(aws elbv2 describe-load-balancers --names sample-elb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null)
if [ "$LB_ARN" == "None" ] || [ -z "$LB_ARN" ]; then
    echo "Creating new Load Balancer..."
    LB_ARN=$(aws elbv2 create-load-balancer --name sample-elb --subnets $PUB01_ID $PUB02_ID --security-groups $SG_ELB_ID --scheme internet-facing --type application --query 'LoadBalancers[0].LoadBalancerArn' --output text)
fi
echo "Load Balancer ARN: $LB_ARN"

# --- 2. 後半の処理（ここからは「上書き」や「追加」なのでエラーが出ても進める） ---

# ターゲット登録（重複しててもエラーになるだけで実害なし）
aws elbv2 register-targets --target-group-arn $TG_ARN --targets Id=$WEB01_ID 2>/dev/null

# リスナー作成（既にあればエラーになるが、変数は維持される）
aws elbv2 create-listener --load-balancer-arn $LB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TG_ARN 2>/dev/null

# Web用SG IDの取得（実体から）
SG_WEB_ID=$(aws ec2 describe-instances --instance-ids $WEB01_ID --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)

# 穴あけ
aws ec2 authorize-security-group-ingress --group-id $SG_WEB_ID --protocol tcp --port 3000 --source-group $SG_ELB_ID 2>/dev/null

echo "------------------------------------------------"
echo "Setup Complete!"
echo "Access URL: http://$(aws elbv2 describe-load-balancers --names sample-elb --query 'LoadBalancers[0].DNSName' --output text)"
echo "------------------------------------------------"
