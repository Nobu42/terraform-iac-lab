## セキュリティグループ設定
| 項目 | 踏み台サーバー用 | ロードバランサー用 |
| :--- | :--- | :--- |
| **名前タグ** | `sample-sg-bastion` | `sample-sg-elb` |
| **説明** | for bastion server | for load balancer |
| **VPC** | `sample-vpc` | `sample-vpc` |
| **インバウンド 1** | SSH (22) / 0.0.0.0/0 | HTTP (80) / 0.0.0.0/0 |
| **インバウンド 2** | - | HTTPS (443) / 0.0.0.0/0 |
```
#!/bin/bash

# 0. VPC IDの再取得
VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=sample-vpc --query 'Vpcs[0].VpcId' --output text)

# --- 1. 踏み台サーバー用 SG 作成 ---
SG_BASTION_ID=$(aws ec2 create-security-group \
    --group-name sample-sg-bastion \
    --description "for bastion server" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=sample-sg-bastion}]' \
    --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress \
    --group-id $SG_BASTION_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

# --- 2. ロードバランサー用 SG 作成 ---
SG_ELB_ID=$(aws ec2 create-security-group \
    --group-name sample-sg-elb \
    --description "for load balancer" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=sample-sg-elb}]' \
    --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress \
    --group-id $SG_ELB_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id $SG_ELB_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

echo "Security Groups created: Bastion($SG_BASTION_ID), ELB($SG_ELB_ID)"

# --- 確認表示 ---
aws ec2 describe-security-groups \
    --group-ids $SG_BASTION_ID $SG_ELB_ID \
    --query 'SecurityGroups[*].{Name:GroupName, ID:GroupId, Rules:IpPermissions[*].{FromPort:FromPort, Cidr:IpRanges[0].CidrIp}}' \
    --output table
```

