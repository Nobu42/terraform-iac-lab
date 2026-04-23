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
```

### 正常に接続されたかの確認

```
aws ec2 describe-internet-gateways \
    --internet-gateway-ids $IGW_ID \
    --query 'InternetGateways[0].Attachments[0].State' \
    --output text
```

##  NATゲートウェイの作成

| 項目 | NATゲートウェイ 1 | NATゲートウェイ 2 |
| :--- | :--- | :--- |
| **名前** | sample-ngw-01 | sample-ngw-02 |
| **サブネット** | sample-subnet-public01 | sample-subnet-public02 |
| **接続タイプ** | パブリック | パブリック |
| **Elastic IP** | 自動生成 | 自動生成 |

```
# 0. サブネットIDの再取得（念のため最新のものを変数に入れる）
PUB01_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public01 --query 'Subnets[0].SubnetId' --output text)
PUB02_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public02 --query 'Subnets[0].SubnetId' --output text)

# --- NAT Gateway 01 (AZ-1a用) ---
# 1. EIPの確保
ALLOC_ID_01=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)

# 2. NAT GWの作成
NGW01_ID=$(aws ec2 create-nat-gateway \
    --subnet-id $PUB01_ID \
    --allocation-id $ALLOC_ID_01 \
    --query 'NatGateway.NatGatewayId' --output text)

# 3. 名前タグ付与
aws ec2 create-tags --resources $NGW01_ID --tags Key=Name,Value=sample-ngw-01


# --- NAT Gateway 02 (AZ-1c用) ---
# 4. EIPの確保
ALLOC_ID_02=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)

# 5. NAT GWの作成
NGW02_ID=$(aws ec2 create-nat-gateway \
    --subnet-id $PUB02_ID \
    --allocation-id $ALLOC_ID_02 \
    --query 'NatGateway.NatGatewayId' --output text)

# 6. 名前タグ付与
aws ec2 create-tags --resources $NGW02_ID --tags Key=Name,Value=sample-ngw-02

echo "NAT Gateways created: $NGW01_ID, $NGW02_ID"
```

### 作成状態の確認
```
aws ec2 describe-nat-gateways \
    --query 'NatGateways[*].{Name:Tags[?Key==`Name`].Value | [0], State:State, Subnet:SubnetId, PublicIP:NatGatewayAddresses[0].PublicIp}' \
    --output table
```
## ルートテーブル設定
| 項目 | パブリック用 (共通) | プライベート用 1 | プライベート用 2 |
| :--- | :--- | :--- | :--- |
| **名前タグ** | `sample-rt-public` | `sample-rt-private01` | `sample-rt-private02` |
| **ルート (local)** | 10.0.0.0/16 (local) | 10.0.0.0/16 (local) | 10.0.0.0/16 (local) |
| **ルート (外部)** | 0.0.0.0/0 (sample-igw) | 0.0.0.0/0 (sample-ngw-01) | 0.0.0.0/0 (sample-ngw-02) |
| **関連付けサブネット** | sample-subnet-public01<br>sample-subnet-public02 | sample-subnet-private01 | sample-subnet-private02 |
### パブリック
```
# 1. ルートテーブルの作成
RT_PUB_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --query 'RouteTable.RouteTableId' \
    --output text)

# 2. 名前タグの付与
aws ec2 create-tags --resources $RT_PUB_ID --tags Key=Name,Value=sample-rt-public

# 3. インターネットゲートウェイへのルートを追加
# (0.0.0.0/0 の出口を IGW に設定)
aws ec2 create-route \
    --route-table-id $RT_PUB_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

# 4. サブネットへの関連付け (Public 01)
aws ec2 associate-route-table \
    --subnet-id $PUB01_ID \
    --route-table-id $RT_PUB_ID

# 5. サブネットへの関連付け (Public 02)
aws ec2 associate-route-table \
    --subnet-id $PUB02_ID \
    --route-table-id $RT_PUB_ID

echo "Public Route Table configured: $RT_PUB_ID"
```
#### 設定の確認
```
aws ec2 describe-route-tables \
    --route-table-ids $RT_PUB_ID \
    --query 'RouteTables[0].Routes' \
    --output table
```
### プライベート
```
# --- Private Route Table 01 (for AZ-1a) ---
# 1. ルートテーブルの作成
RT_PRI01_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
# 2. 名前タグ付与
aws ec2 create-tags --resources $RT_PRI01_ID --tags Key=Name,Value=sample-rt-private01
# 3. NATゲートウェイ(01)へのルート追加
aws ec2 create-route --route-table-id $RT_PRI01_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NGW01_ID
# 4. サブネット(Private01)への関連付け
aws ec2 associate-route-table --subnet-id $PRI01_ID --route-table-id $RT_PRI01_ID

# --- Private Route Table 02 (for AZ-1c) ---
# 5. ルートテーブルの作成
RT_PRI02_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
# 6. 名前タグ付与
aws ec2 create-tags --resources $RT_PRI02_ID --tags Key=Name,Value=sample-rt-private02
# 7. NATゲートウェイ(02)へのルート追加
aws ec2 create-route --route-table-id $RT_PRI02_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NGW02_ID
# 8. サブネット(Private02)への関連付け
aws ec2 associate-route-table --subnet-id $PRI02_ID --route-table-id $RT_PRI02_ID

echo "Private Route Tables configured: $RT_PRI01_ID, $RT_PRI02_ID"
```

#### 設定の確認
```
aws ec2 describe-route-tables \
    --filters Name=vpc-id,Values=$VPC_ID \
    --query 'RouteTables[*].{Name:Tags[?Key==`Name`].Value | [0], Routes:Routes[?DestinationCidrBlock==`0.0.0.0/0`].[GatewayId,NatGatewayId] | [0]}' \
    --output table
```

