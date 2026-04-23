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
## サブネット作成
### 外部サブネット 1
- **サブネット名:** sample-subnet-public01
- **AZ:**           ap-northeast-1a
- **IPv4 CIDR:**    10.0.0.0/20

### 外部サブネット 2
- **サブネット名:** sample-subnet-public02
- **AZ:**           ap-northeast-1c
- **IPv4 CIDR:**    10.0.16.0/20

### 内部サブネット 1
- **サブネット名:** sample-subnet-private01
- **AZ:**           ap-northeast-1a
- **IPv4 CIDR:**    10.0.64.0/20

### 内部サブネット 2
- **サブネット名:** sample-subnet-private02
- **AZ:**           ap-northeast-1c
- **IPv4 CIDR:**    10.0.80.0/20

### 4つのサブネットを一括作成
```
# 0. VPC IDの再取得（念のため）
VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=sample-vpc --query 'Vpcs[0].VpcId' --output text)

# 1. 外部サブネット 1 (1a)
PUB01_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.0.0/20 --availability-zone ap-northeast-1a --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $PUB01_ID --tags Key=Name,Value=sample-subnet-public01

# 2. 外部サブネット 2 (1c)
PUB02_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.16.0/20 --availability-zone ap-northeast-1c --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $PUB02_ID --tags Key=Name,Value=sample-subnet-public02

# 3. 内部サブネット 1 (1a)
PRI01_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.64.0/20 --availability-zone ap-northeast-1a --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $PRI01_ID --tags Key=Name,Value=sample-subnet-private01

# 4. 内部サブネット 2 (1c)
PRI02_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.80.0/20 --availability-zone ap-northeast-1c --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $PRI02_ID --tags Key=Name,Value=sample-subnet-private02
```
### 作成結果の確認
```
aws ec2 describe-subnets \
    --filters Name=vpc-id,Values=$VPC_ID \
    --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value | [0], AZ:AvailabilityZone, CIDR:CidrBlock, ID:SubnetId}' \
    --output table
```

## インターネットゲートウェイの作成

- **名前タグ:** sample-igw
- **VPC:** sample-vpc

```
# 1. ターゲットとなるVPCのIDを取得
VPC_ID=$(aws ec2 describe-vpcs \
    --filters Name=tag:Name,Values=sample-vpc \
    --query 'Vpcs[0].VpcId' \
    --output text)

# 2. インターネットゲートウェイ(IGW)を作成し、IDを変数に格納
IGW_ID=$(aws ec2 create-internet-gateway \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

# 3. IGWに名前タグ「sample-igw」を付与
aws ec2 create-tags \
    --resources $IGW_ID \
    --tags Key=Name,Value=sample-igw

# 4. 作成したIGWをVPCにアタッチ（接続）
aws ec2 attach-internet-gateway \
    --vpc-id $VPC_ID \
    --internet-gateway-id $IGW_ID

echo "Success! Attached IGW ($IGW_ID) to VPC ($VPC_ID)"

### 正常に接続されたかの確認

```
aws ec2 describe-internet-gateways \
    --internet-gateway-ids $IGW_ID \
    --query 'InternetGateways[0].Attachments[0].State' \
    --output text
```
