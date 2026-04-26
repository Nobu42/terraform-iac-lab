#!/bin/bash

# 1. リスナーの作成（80番ポートの受付開始）
echo "Creating Listener..."
aws elbv2 create-listener \
    --load-balancer-arn $LB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN

# 2. セキュリティグループの連動（LBからWebサーバーへの3000番を許可）
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

# 3. 最後にアクセス用URLを表示
DNS_NAME=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $LB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "------------------------------------------------"
echo "Setup Complete!"
echo "Access URL: http://$DNS_NAME"
echo "------------------------------------------------"
