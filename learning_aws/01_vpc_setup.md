# AWS VPC 環境設定

## VPC設定値
- **Name Tag:** sample-vpc
- **IPv4 CIDR:** 10.0.0.0/16
- **Tenancy:** default


```
# デフォルトリージョンを東京に設定
aws configure set region ap-northeast-1

# 現在の設定を確認
aws configure get region
```

## VPC構築 (vpc_create.sh)
> **Note:** LocalStack環境では `--region ap-northeast-1` を明示するか、`aws configure` で事前に設定しておく必要があります。

```bash
#!/bin/bash

# 1. VPCの作成とタグ付与を同時に実行
# 作成時にタグを付けることで、管理ミスを防ぎます
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --instance-tenancy default \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=sample-vpc}]' \
    --query 'Vpc.VpcId' \
    --output text)

# 2. 作成されたIDの確認
echo "New VPC ID: $VPC_ID"

# 3. DNSサポートの有効化（ALBやRDSを使う際に重要！）
# ※LocalStackでもこれを有効にしておくと、本番環境に近い挙動になります
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames '{"Value":true}'
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support '{"Value":true}'

# 4. 最終確認
# ID、名前、状態、DNS設定を一覧で表示
aws ec2 describe-vpcs \
    --vpc-ids $VPC_ID \
    --query 'Vpcs[*].{ID:VpcId, Name:Tags[?Key==`Name`].Value | [0], CIDR:CidrBlock, DNSHost:EnableDnsHostnames}' \
    --output table
```

