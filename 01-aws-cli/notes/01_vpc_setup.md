# 01 VPC Setup

## 目的

AWS CLIでVPCを作成し、CIDR、タグ、DNS設定を確認する。

## 実行環境

- LocalStack
- Region: ap-northeast-1

## 設定値

- Name: sample-vpc
- CIDR: 10.0.0.0/16
- Tenancy: default
- DNS Hostnames: enabled
- DNS Support: enabled

## スクリプト

- [01_vpc_setup.sh](../scripts/01_vpc_setup.sh)

## 実行コマンド

```bash
./01_vpc_setup.sh
```

## 確認コマンド
```
aws ec2 describe-vpcs \
  --filters Name=tag:Name,Values=sample-vpc \
  --query 'Vpcs[*].{ID:VpcId,Name:Tags[?Key==`Name`].Value|[0],CIDR:CidrBlock,State:State}' \
  --output table
```
