#!/bin/bash

echo "Creating RDS Instance (sample-db)..."

aws --endpoint-url=http://localhost:4566 rds create-db-instance \
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
# 状態確認（簡易版）
aws --endpoint-url=http://localhost:4566 rds wait db-instance-exists --db-instance-identifier sample-db
echo "RDS Instance created successfully."
