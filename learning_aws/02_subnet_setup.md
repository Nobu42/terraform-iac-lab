## サブネット設計一覧

| 区分 | サブネット名 | 可用性ゾーン (AZ) | IPv4 CIDR |
| :--- | :--- | :--- | :--- |
| **外部 (Public) 1** | sample-subnet-public01 | ap-northeast-1a | 10.0.0.0/20 |
| **外部 (Public) 2** | sample-subnet-public02 | ap-northeast-1c | 10.0.16.0/20 |
| **内部 (Private) 1** | sample-subnet-private01 | ap-northeast-1a | 10.0.64.0/20 |
| **内部 (Private) 2** | sample-subnet-private02 | ap-northeast-1c | 10.0.80.0/20 |

---

### 4つのサブネットを一括作成 (Shell/02_subnet_setup.sh)

```
#!/bin/bash

# 0. VPC IDの再取得
VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=sample-vpc --query 'Vpcs[0].VpcId' --output text)

# 1. 外部サブネット 1 (1a) + タグ同時付与 + パブリックIP自動割当有効化
PUB01_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.0.0/20 \
    --availability-zone ap-northeast-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sample-subnet-public01}]' \
    --query 'Subnet.SubnetId' --output text)

aws ec2 modify-subnet-attribute --subnet-id $PUB01_ID --map-public-ip-on-launch

# 2. 外部サブネット 2 (1c)
PUB02_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.16.0/20 \
    --availability-zone ap-northeast-1c \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sample-subnet-public02}]' \
    --query 'Subnet.SubnetId' --output text)

aws ec2 modify-subnet-attribute --subnet-id $PUB02_ID --map-public-ip-on-launch

# 3. 内部サブネット 1 (1a)
PRI01_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.64.0/20 \
    --availability-zone ap-northeast-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sample-subnet-private01}]' \
    --query 'Subnet.SubnetId' --output text)

# 4. 内部サブネット 2 (1c)
PRI02_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.80.0/20 \
    --availability-zone ap-northeast-1c \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=sample-subnet-private02}]' \
    --query 'Subnet.SubnetId' --output text)

echo "Subnets created: Public($PUB01_ID, $PUB02_ID), Private($PRI01_ID, $PRI02_ID)"
```
### 作成結果の確認
```
aws ec2 describe-subnets \
    --filters Name=vpc-id,Values=$VPC_ID \
    --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value | [0], AZ:AvailabilityZone, CIDR:CidrBlock, ID:SubnetId}' \
    --output table
```

