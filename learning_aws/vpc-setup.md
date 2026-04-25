# とりあえずのメモ書き。後日、設定ごとにまとめる予定。
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
##  VPC再構築コマンド（一括実行用）
```
# 1. VPCの作成（作成したIDを変数 VPC_ID に格納）
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --instance-tenancy default \
    --query 'Vpc.VpcId' \
    --output text)

# 2. 作成されたIDの確認（画面に表示される）
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
# ネットワーク構築
```
[ VPC: sample-vpc (10.0.0.0/16) ]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    │
    │  [ Internet Gateway: sample-igw ] <───> ( Internet )
    │
    ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [ Route Table: sample-rt-public ]                        │
  │  - 0.0.0.0/0  =>  sample-igw                             │
  └──────────────────────────┬───────────────────────────────┘
                             │
            ┌────────────────┴────────────────┐
            ▼                                 ▼
    [ Public Subnet 01 ]              [ Public Subnet 02 ]
    ( 10.0.11.0/24 )                  ( 10.0.12.0/24 )
    [sample-subnet-public01]          [sample-subnet-public02]
    ┌──────────────────┐              ┌──────────────────┐
    │ [SG: sg-bastion] │              │ [SG: sg-elb]     │
    └──────────────────┘              └──────────────────┘
            │                                 │
            ▼                                 ▼
    [ NAT Gateway 01 ]                [ NAT Gateway 02 ]
    (sample-ngw-01)                   (sample-ngw-02)
            │                                 │
━━━━━━━━━━━━│━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│━━━━━━━━━━━━━━━
            │                                 │
  ┌─────────▼───────────────────────┐ ┌─────────▼───────────────────────┐
  │[Route Table: sample-rt-private01]│ │[Route Table: sample-rt-private02]│
  │ - 0.0.0.0/0 => sample-ngw-01     │ │ - 0.0.0.0/0 => sample-ngw-02     │
  └─────────┬───────────────────────┘ └─────────┬───────────────────────┘
            │                                   │
            ▼                                   ▼
    [ Private Subnet 01 ]               [ Private Subnet 02 ]
    ( 10.0.21.0/24 )                    ( 10.0.22.0/24 )
    [sample-subnet-private01]           [sample-subnet-private02]
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
## セキュリティグループ設定
| 項目 | 踏み台サーバー用 | ロードバランサー用 |
| :--- | :--- | :--- |
| **名前タグ** | `sample-sg-bastion` | `sample-sg-elb` |
| **説明** | for bastion server | for load balancer |
| **VPC** | `sample-vpc` | `sample-vpc` |
| **インバウンド 1** | SSH (22) / 0.0.0.0/0 | HTTP (80) / 0.0.0.0/0 |
| **インバウンド 2** | - | HTTPS (443) / 0.0.0.0/0 |
```
# --- 1. 踏み台サーバー用 SG 作成 ---
SG_BASTION_ID=$(aws ec2 create-security-group \
    --group-name sample-sg-bastion \
    --description "for bastion server" \
    --vpc-id $VPC_ID \
    --query 'GroupId' --output text)

# SSH(22番ポート)を全開放
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
    --query 'GroupId' --output text)

# HTTP(80番ポート)を全開放
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ELB_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# HTTPS(443番ポート)を全開放
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ELB_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

echo "Security Groups created: Bastion($SG_BASTION_ID), ELB($SG_ELB_ID)"
```
### 設定の確認
```
aws ec2 describe-security-groups \
    --group-ids $SG_BASTION_ID $SG_ELB_ID \
    --query 'SecurityGroups[*].{Name:GroupName, Rules:IpPermissions[*].{Port:FromPort, Range:IpRanges[0].CidrIp}}' \
    --output table
```

# サーバ構築

## 踏み台サーバー（Bastion）の作成

### キーペア設計
| 項目 | 設定内容 |
| :--- | :--- |
| **名前** | `nobu` |
| **タイプ** | RSA |
| **形式** | `.pem` |

### EC2 インスタンス設計：sample-ec2-bastion
| 項目 | 設定内容 |
| :--- | :--- |
| **名前タグ** | `sample-ec2-bastion` |
| **AMI ID** | `ami-0ff227f0771efc640` |
| **タイプ** | `t2.micro` |
| **キーペア** | `nobu` |
| **サブネット** | `sample-subnet-public01` |
| **パブリックIP** | 有効 |
| **セキュリティグループ** | `sample-sg-bastion` |

```
# CLIでAMI IDを確認するコマンド
aws ec2 describe-images --query 'Images[*].[ImageId,Name]' --output table
```

```
# CLIでAMIを絞り込む方法(--filtersで絞り込み)
aws ec2 describe-images \
    --filters "Name=name,Values=amzn2-ami-hvm*" \
    --query 'Images[*].[ImageId,Name]' \
    --output table

BASTION_ID=$(aws ec2 run-instances \
    --image-id ami-0ff227f0771efc640 \
    --count 1 \
    --instance-type t2.micro \
    --key-name nobu \
    --security-group-ids $SG_BASTION_ID \
    --subnet-id $PUB01_ID \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sample-ec2-bastion}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Bastion Instance Created: $BASTION_ID"
```
```

# LocalStack(AWS)側から既存のキーペアを削除（エラーが出ても無視する）
aws ec2 delete-key-pair --key-name nobu > /dev/null 2>&1
# mac側（クライアント）も削除
rm -f nobu.pem
# 1. キーペアの作成と保存
aws ec2 create-key-pair \
    --key-name nobu \
    --query 'KeyMaterial' \
    --output text > nobu.pem

# パーミッションを自分だけが読み取れる設定に変更（必須）
chmod 400 nobu.pem

# 2. 踏み台サーバーの起動
# --associate-public-ip-address でパブリックIPを有効化する
# 踏み台サーバーの起動
# 【重要】--image-id を LocalStack が「コンテナ」として認識できる ID に変更する
# Amazon Linux 2 の LocalStack 用デフォルト ID: ami-07b643b5e45e
BASTION_ID=$(aws ec2 run-instances \
    --image-id ami-07b643b5e45e \
    --count 1 \
    --instance-type t2.micro \
    --key-name nobu \
    --security-group-ids $SG_BASTION_ID \
    --subnet-id $PUB01_ID \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sample-ec2-bastion}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Bastion Instance Created: $BASTION_ID"
```
### 起動確認

```
aws ec2 describe-instances \
    --instance-ids $BASTION_ID \
    --query 'Reservations[0].Instances[0].{Status:State.Name, PublicIP:PublicIpAddress}' \
    --output table
```
### 接続確認
```
# Ubuntu側でdocker psで以下を確認
# 0.0.0.0:60577->22/tcp, [::]:60577->22/tcp

# Macのターミナルから実行
ssh -i nobu.pem -p 60577 root@192.168.40.100

# 1. OSのリリース情報を確認（これで Amazon Linux 2 であることが分かる）
cat /etc/system-release

# 2. ネットワーク設定を確認（IPが見えるはず）
ip addr show eth0

# 3. CPU情報を確認
cat /proc/cpuinfo | grep "model name"
```
### ユーザー作成（本物に似せるため、ec2-userを作成する）
```
# 1. ec2-user という名前のユーザーを作成
useradd ec2-user

# 2. ec2-user が sudo（管理者権限）を使えるように設定
# (LocalStackのコンテナ環境では /etc/sudoers をいじるより、グループ追加が手っ取り早い)
yum install -y sudo
echo "ec2-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 3. ec2-user に切り替える
su - ec2-user
```
```
# 1. ec2-userのSSH設定ディレクトリを作成
mkdir -p /home/ec2-user/.ssh
chmod 700 /home/ec2-user/.ssh

# 2. rootが持っている「許可された鍵リスト」を ec2-user にコピー
cp /root/.ssh/authorized_keys /home/ec2-user/.ssh/
chown -R ec2-user:ec2-user /home/ec2-user/.ssh
chmod 600 /home/ec2-user/.ssh/authorized_keys

# パスワードを「password」に設定する場合
echo "ec2-user:password" | chpasswd
```
## Webサーバー構築（EC2）

| 項目 | 設定値 | 備考 |
|:---|:---|:---|
| **名前 (Name)** | `sample-ec2-web01` / `sample-ec2-web02` | 2台構成 |
| **Amazon Machine Image (AMI)** | `ami-07b643b5e45e` | LocalStack専用 Amazon Linux 2 |
| **インスタンスタイプ** | `t2.micro` | 適宜 |
| **キーペア** | `nobu` | 踏み台サーバーと共通 |
| **VPC** | `sample-vpc` | |
| **サブネット** | `sample-subnet-private01` (web01用)<br>`sample-subnet-private02` (web02用) | マルチAZ配置 |
| **パブリックIPの自動割り当て** | **無効化** | プライベートサブネットのため |
| **セキュリティグループ** | `default` | 必要に応じて後ほど修正 |

```
# Webサーバー01 (Private Subnet 1)
WEB01_ID=$(aws ec2 run-instances \
    --image-id ami-07b643b5e45e \
    --count 1 \
    --instance-type t2.micro \
    --key-name nobu \
    --subnet-id $PRIV01_ID \
    --no-associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sample-ec2-web01}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

# Webサーバー02 (Private Subnet 2)
WEB02_ID=$(aws ec2 run-instances \
    --image-id ami-07b643b5e45e \
    --count 1 \
    --instance-type t2.micro \
    --key-name nobu \
    --subnet-id $PRIV02_ID \
    --no-associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sample-ec2-web02}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Created Web01: $WEB01_ID"
echo "Created Web02: $WEB02_ID"

# Nameタグを指定してIDを自動取得する（Mac側） これないとやってらんねーーー！！！
BASTION_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=sample-ec2-bastion" --query 'Reservations[].Instances[].InstanceId' --output text)
WEB01_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=sample-ec2-web01" --query 'Reservations[].Instances[].InstanceId' --output text)
WEB02_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=sample-ec2-web02" --query 'Reservations[].Instances[].InstanceId' --output text)
# これでUbuntu側にec2ユーザーを作る。Ubuntu側にsetup_user.shの配置を忘れない！
for id in $BASTION_ID $WEB01_ID $WEB02_ID; do
    echo "Processing $id..."
    ssh nobu@192.168.40.100 "bash ~/setup_user.sh $id"
done
```
### 鍵の作成
```
# Enter file in which to save... → 何も打たずに Enter
# Enter passphrase... → 何も打たずに Enter
# Enter same passphrase... → 何も打たずに Enter
ssh-keygen -t ed25519

# Ubuntuへ転送
ssh-copy-id nobu@192.168.40.100

# パスワードなしで入れるか確認
ssh nobu@192.168.40.100
```
### macの~/.bashrc追記
```
# ls-startでlocalstackスタート！
alias ls-start="ssh nobu@192.168.40.100 'bash ~/start_terraform.sh'"
# lsp でUbuntuのEC2インスタンスに接続するためのポート情報を出力
alias lsp="ssh nobu@192.168.40.100 'docker ps --filter name=localstack-ec2 --format \"table {{.Names}}\t{{.Ports}}\"'"
```
### 多段接続用
mac の~/.ssh/configに以下を追記
```
# --- (1) 踏み台サーバー (Bastion) ---
Host bastion
    HostName 192.168.40.100
    User ec2-user
    Port 32805                # ここを lsp で確認した bastion のポートに！
    IdentityFile ~/terraform-iac-lab/nobu.pem

# --- (2) Webサーバー 01 ---
Host web01
    HostName 172.17.0.4       # ec2_status.sh で確認した IP
    User ec2-user
    IdentityFile ~/terraform-iac-lab/nobu.pem
    ProxyJump bastion         # 最近の SSH では ProxyCommand よりこれが標準！

# --- (3) Webサーバー 02 ---
Host web02
    HostName 172.17.0.5       # ec2_status.sh で確認した IP
    User ec2-user
    IdentityFile ~/terraform-iac-lab/nobu.pem
    ProxyJump bastion
```

## ロードバランサー

```
# --- 1. 必要な ID を再取得して変数に叩き込む ---
VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=sample-vpc --query 'Vpcs[0].VpcId' --output text)
PUB01_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public01 --query 'Subnets[0].SubnetId' --output text)
PUB02_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public02 --query 'Subnets[0].SubnetId' --output text)
WEB01_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=sample-ec2-web01 --query 'Reservations[0].Instances[0].InstanceId' --output text)
WEB02_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=sample-ec2-web02 --query 'Reservations[0].Instances[0].InstanceId' --output text)

# --- 2. ターゲットグループを作成 ---
TG_ARN=$(aws elbv2 create-target-group \
    --name sample-tg \
    --protocol HTTP \
    --port 3000 \
    --vpc-id $VPC_ID \
    --health-check-protocol HTTP \
    --health-check-path / \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo "Target Group ARN: $TG_ARN"

# --- 3. Webサーバーを登録 ---
aws elbv2 register-targets \
    --target-group-arn $TG_ARN \
    --targets Id=$WEB01_ID Id=$WEB02_ID

# --- 4. LB用セキュリティグループの ID を取得 ---
SG_ELB_ID=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=sample-sg-elb \
    --query 'SecurityGroups[0].GroupId' --output text)

# --- 5. ロードバランサー（ALB）本体の作成 ---
LB_ARN=$(aws elbv2 create-load-balancer \
    --name sample-elb \
    --subnets $PUB01_ID $PUB02_ID \
    --security-groups $SG_ELB_ID \
    --scheme internet-facing \
    --type application \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

echo "Load Balancer ARN: $LB_ARN"


# 1. リスナーの作成（80番ポートの受付開始）
echo "Creating Listener..."
aws elbv2 create-listener \
    --load-balancer-arn $LB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN

# 2. セキュリティグループの連動（LBからWebサーバーへの3000番を許可）
# ※Webサーバーが使っているSG名を「sample-sg-web」と仮定しています。適宜直してください。
SG_WEB_ID=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=sample-sg-web \
    --query 'SecurityGroups[0].GroupId' --output text)

echo "Allowing traffic from LB SG ($SG_ELB_ID) to Web SG ($SG_WEB_ID) on Port 3000..."
aws ec2 authorize-security-group-ingress \
    --group-id $SG_WEB_ID \
    --protocol tcp \
    --port 3000 \
    --source-group $SG_ELB_ID

# 3. 最後にアクセス用URLを表示
DNS_NAME=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $LB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "------------------------------------------------"
echo "Setup Complete!"
echo "Access URL: http://$DNS_NAME"
echo "------------------------------------------------"
```
