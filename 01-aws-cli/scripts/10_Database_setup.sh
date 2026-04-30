#!/bin/bash

### DBパラメータグループの作成
aws --endpoint-url=http://192.168.40.100:4566 rds create-db-parameter-group \
    --db-parameter-group-name sample-db-pg \
    --db-parameter-group-family mysql8.0 \
    --description "sample parameter group"

### DBオプショングループの作成
aws --endpoint-url=http://192.168.40.100:4566 rds create-option-group \
    --option-group-name sample-db-og \
    --engine-name mysql \
    --major-engine-version 8.0 \
    --option-group-description "sample option group"

### DBサブネットグループの作成
# サブネットIDの取得
SUBNET_PRIV01=$(aws --endpoint-url=http://192.168.40.100:4566 ec2 describe-subnets --filters "Name=tag:Name,Values=sample-subnet-private01" --query "Subnets[0].SubnetId" --output text)
SUBNET_PRIV02=$(aws --endpoint-url=http://192.168.40.100:4566 ec2 describe-subnets --filters "Name=tag:Name,Values=sample-subnet-private02" --query "Subnets[0].SubnetId" --output text)

# サブネットグループの作成
aws --endpoint-url=http://192.168.40.100:4566 rds create-db-subnet-group \
    --db-subnet-group-name sample-db-subnet \
    --db-subnet-group-description "sample db subnet" \
    --subnet-ids "$SUBNET_PRIV01" "$SUBNET_PRIV02"

# DB用のセキュリティグループ作成（未作成なら）
# DB_SG_ID=$(aws ec2 create-security-group --group-name sample-sg-db --description "Security group for DB" --vpc-id $VPC_ID ...)

# WebサーバーのSGからのアクセスを許可
# aws ec2 authorize-security-group-ingress --group-id $DB_SG_ID --protocol tcp --port 3306 --source-group $WEB_SG_ID

echo "Creating RDS Instance (sample-db)..."

aws --endpoint-url=http://192.168.40.100:4566 rds create-db-instance \
    --db-instance-identifier sample-db \
    --engine mysql \
    --db-instance-class db.t2.micro \
    --allocated-storage 20 \
    --master-username admin \
    --master-user-password Terraform-iac-lab42 \
    --db-subnet-group-name sample-db-subnet \
    --db-parameter-group-name sample-db-pg \
    --option-group-name sample-db-og \
    --no-publicly-accessible \
    --backup-retention-period 0

echo "Waiting for RDS instance to be available..."
# 状態確認
aws --endpoint-url=http://192.168.40.100:4566 rds wait db-instance-available --db-instance-identifier sample-db
echo "RDS Instance created successfully."
