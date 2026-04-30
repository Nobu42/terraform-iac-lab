## インターネットゲートウェイの作成

- **名前タグ:** sample-igw
- **VPC:** sample-vpc

```
#!/bin/bash

# 1. ターゲットとなるVPCのIDを取得
VPC_ID=$(aws ec2 describe-vpcs \
    --filters Name=tag:Name,Values=sample-vpc \
    --query 'Vpcs[0].VpcId' \
    --output text)

# 2. インターネットゲートウェイ(IGW)を作成し、タグも同時に付与
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=sample-igw}]' \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

# 3. 作成したIGWをVPCにアタッチ（接続）
aws ec2 attach-internet-gateway \
    --vpc-id $VPC_ID \
    --internet-gateway-id $IGW_ID

echo "Success! Attached IGW ($IGW_ID) to VPC ($VPC_ID)"

# 4. 正常に接続されたかの確認（ID, VPC ID, 状態を表示）
aws ec2 describe-internet-gateways \
    --internet-gateway-ids $IGW_ID \
    --query 'InternetGateways[*].{ID:InternetGatewayId, VPC:Attachments[0].VpcId, State:Attachments[0].State}' \
    --output table
```

