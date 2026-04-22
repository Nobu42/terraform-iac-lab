# AWS CLIによる設定作業

## VPC設定値
- **Name Tag:** sample-vpc
- **IPv4 CIDR:** 10.0.0.0/16
- **Tenancy:** default


## AWS CLI 環境設定
```
# デフォルトリージョンを東京に設定
aws configure set region ap-northeast-1

# 現在の設定を確認
aws configure get region
```
##  VPC再構築コマンド（一括実行用）
```
# 1. VPCの作成（作成したIDを変数 VPC_ID に格納）
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --instance-tenancy default \
    --query 'Vpc.VpcId' \
    --output text)

# 2. 作成されたIDの確認（画面に表示されます）
echo "New VPC ID in Tokyo: $VPC_ID"

# 3. 名前タグ（sample-vpc）を付与
aws ec2 create-tags \
    --resources $VPC_ID \
    --tags Key=Name,Value=sample-vpc

# 4. 最終確認（タグや設定が反映されているか）
aws ec2 describe-vpcs --vpc-ids $VPC_ID
```
##  状態確認・デバッグ用
```
# 名前が「sample-vpc」であるVPCを一覧表示
aws ec2 describe-vpcs --filters Name=tag:Name,Values=sample-vpc

# 全てのVPCのIDと名前、CIDRを一覧で表示（表形式）
aws ec2 describe-vpcs --query 'Vpcs[*].{ID:VpcId, Name:Tags[?Key==`Name`].Value | [0], CIDR:CidrBlock}' --output table
```
