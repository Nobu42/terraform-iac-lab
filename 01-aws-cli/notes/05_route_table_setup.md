## ルートテーブル設定
| 項目 | パブリック用 (共通) | プライベート用 1 | プライベート用 2 |
| :--- | :--- | :--- | :--- |
| **名前タグ** | `sample-rt-public` | `sample-rt-private01` | `sample-rt-private02` |
| **ルート (local)** | 10.0.0.0/16 (local) | 10.0.0.0/16 (local) | 10.0.0.0/16 (local) |
| **ルート (外部)** | 0.0.0.0/0 (sample-igw) | 0.0.0.0/0 (sample-ngw-01) | 0.0.0.0/0 (sample-ngw-02) |
| **関連付けサブネット** | sample-subnet-public01<br>sample-subnet-public02 | sample-subnet-private01 | sample-subnet-private02 |

```
#!/bin/bash

# --- 0. 必要なIDを名前タグから再取得 ---
VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=sample-vpc --query 'Vpcs[0].VpcId' --output text)
IGW_ID=$(aws ec2 describe-internet-gateways --filters Name=tag:Name,Values=sample-igw --query 'InternetGateways[0].InternetGatewayId' --output text)
NGW01_ID=$(aws ec2 describe-nat-gateways --filter Name=tag:Name,Values=sample-ngw-01 --query 'NatGateways[0].NatGatewayId' --output text)
NGW02_ID=$(aws ec2 describe-nat-gateways --filter Name=tag:Name,Values=sample-ngw-02 --query 'NatGateways[0].NatGatewayId' --output text)
PUB01_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public01 --query 'Subnets[0].SubnetId' --output text)
PUB02_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public02 --query 'Subnets[0].SubnetId' --output text)
PRI01_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-private01 --query 'Subnets[0].SubnetId' --output text)
PRI02_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-private02 --query 'Subnets[0].SubnetId' --output text)

# --- 1. パブリック用ルートテーブル (IGW経由) ---
RT_PUB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=sample-rt-public}]' \
    --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-route --route-table-id $RT_PUB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --subnet-id $PUB01_ID --route-table-id $RT_PUB_ID
aws ec2 associate-route-table --subnet-id $PUB02_ID --route-table-id $RT_PUB_ID

# --- 2. プライベート用ルートテーブル 01 (NAT-GW-01経由) ---
RT_PRI01_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=sample-rt-private01}]' \
    --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-route --route-table-id $RT_PRI01_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NGW01_ID
aws ec2 associate-route-table --subnet-id $PRI01_ID --route-table-id $RT_PRI01_ID

# --- 3. プライベート用ルートテーブル 02 (NAT-GW-02経由) ---
RT_PRI02_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=sample-rt-private02}]' \
    --query 'RouteTable.RouteTableId' --output text)

aws ec2 create-route --route-table-id $RT_PRI02_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NGW02_ID
aws ec2 associate-route-table --subnet-id $PRI02_ID --route-table-id $RT_PRI02_ID

echo "All Route Tables configured and associated."

# --- 4. 最終確認（名前、ルート、関連付けサブネットを表示） ---
aws ec2 describe-route-tables \
    --filters Name=vpc-id,Values=$VPC_ID \
    --query 'RouteTables[*].{Name:Tags[?Key==`Name`].Value | [0], Subnet:Associations[*].SubnetId | [0], IGW:Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId | [0], NGW:Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId | [0]}' \
    --output table
```

