# AWS CLIによる設定作業

## VPC設定値
- **Name Tag:** sample-vpc
- **IPv4 CIDR:** 10.0.0.0/16
- **Tenancy:** default

## 設定コマンド
```
# 1. VPCの作成
aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --instance-tenancy default

# 2. 名前タグ（sample-vpc）を付与
# ※上記コマンドで出力された「VpcId (vpc-xxxxxx)」を [VPC_ID] に入れてください
aws ec2 create-tags \
    --resources [VPC_ID] \
    --tags Key=Name,Value=sample-vpc

# 3. 作成後の確認コマンド
aws ec2 describe-vpcs --filters Name=tag:Name,Values=sample-vpc

# 4. ログ

aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --instance-tenancy default

aws ec2 create-tags \
    --resources vpc-04680630acab71478 \
    --tags Key=Name,Value=sample-vpc

aws ec2 describe-vpcs --vpc-ids vpc-04680630acab71478
```

