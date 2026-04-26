# Terraform IaC Lab

![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Raspberry Pi](https://img.shields.io/badge/-Raspberry%20Pi-C51A4A?style=for-the-badge&logo=Raspberry-Pi)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E9430F?style=for-the-badge&logo=ubuntu&logoColor=white)

MacBook Air (M4) と自宅の Raspberry Pi 4（DNS）、Ubuntu サーバーを連携させ、
AWS クラウドインフラをシミュレートする IaC（Infrastructure as Code）キャッチアップ環境です。
コンテンツのAWS構築演習でAWSの復習、
Terraform演習でTerraformキャッチアップの予定。
このあとAnsible、Kubernetesも追加予定。随時更新。

##  コンテンツ (演習内容)

### 1. AWS 構築 (LocalStack AWS CLI)
`learning_aws/` ディレクトリにて、シェルスクリプトによる AWS 構成管理を実践。
* **[vimrc](../terraform-iac-lab/dotfiles/vimrc)**
* **[bashrc](../terraform-iac-lab/dotfiles/bashrc)**
* **[01] [VPC 構築](./learning_aws/01_vpc_setup.md)** - ネットワークの土台
* **[02] [サブネット設計](./learning_aws/02_subnet_setup.md)** - Public/Private の切り分け
* **[03] [IGW 設定](./learning_aws/03_internetgateway_setup.md)** - 外の世界への出口
* **[04] [NAT Gateway](./learning_aws/04_nat_gateway_setup.md)** - プライベート空間からの通信確保
* **[05] [ルートテーブル](./learning_aws/05_route_table_setup.md)** - パケットの通り道を定義
* **[06] [セキュリティグループ](./learning_aws/06_security_group_setup.md)** - 仮想ファイアウォール
* **[07] [踏み台サーバー](./learning_aws/07_bastion_server_setup.md)** - セキュアな SSH 入口
* **[08] [Web サーバー (EC2)](./learning_aws/08_web_server_setup.md)** - 内部サーバー構築と多段 SSH
* **[09] [ロードバランサー (ALB)](./learning_aws/09_LoadBalancer_setup.md)** - サービス公開と負荷分散

> **一括構築:** [`./learning_aws/All_Setup.sh`](./learning_aws/All_Setup.sh) を実行することで、全工程を自動で再現可能です。

---

### 2. Terraform 演習
`execises/` ディレクトリにて、HCL によるプロビジョニングを学習します。

* **Basic**: [プロバイダー設定とリソースの基本](./execises/basic/)
* **Syntax**: [変数（Variables）や出力（Outputs）の扱い](./execises/basic_sintax/)
* **Lambda**: [Lambda + IAM + DynamoDB のサーバーレス構成](./execises/localstack_test/)

## Network Topology

```text
      [ MacBook Air (M4) ] <--- クライアント (外出先 / 自宅)
               |
               | (DNS Query)      (AWS CLI / Terraform)
               |                   |
  +------------v-------------+     | +-------------------------+
  |  Raspberry Pi 4 (DNS)    |     | |  Ubuntu Server (Target) |
  |  (192.168.40.208)        |     | |  (192.168.40.100)       |
  |                          |     | |                         |
  |  [ CoreDNS ]             |     | |  [ LocalStack ]         |
  |  localstack.lab -------- | ----+ |  (AWS Simulation)       |
  +--------------------------+       +-------------------------+
               |                                ^
               |                                |
               +---[ Internal Private Network ]--+
```
## LocalStack内部ネットワーク
```
[ VPC: sample-vpc (10.0.0.0/16) ]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    │
    │  [ Internet Gateway ] <───> ( Internet )
    ▼
  ┌──────────────────────────────────────────────────┐
  │ [ Public Subnets ] (Bastion / ALB)               │
  │ 10.0.0.0/20 & 10.0.16.0/20                       │
  └──────────┬──────────────────────────────┬────────┘
             ▼                              ▼
      [ NAT Gateway 01 ]            [ NAT Gateway 02 ]
━━━━━━━━━━━━━│━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│━━━━━━━━━
             ▼                              ▼
  ┌──────────────────────────────────────────────────┐
  │ [ Private Subnets ] (Web Servers)                │
  │ 10.0.64.0/20 & 10.0.80.0/20                      │
  └──────────────────────────────────────────────────┘
```

## コンセプト
- **ハイブリッド設計:** 自宅の Ubuntu (192.168.40.100) と外出先の Mac を自動判別し、エンドポイントを自動切り替え。


## インストールとセットアップ
### Mac (Client Side)
```
brew tap hashicorp/tap
brew install hashicorp/tap/terraform awscli
brew install localstack/tap/localstack-cli
```

### Ubuntu Server (LocalStack) のセットアップ

Ubuntu サーバーを LocalStack 専用のホストとして構築し、外部（Mac）からの接続を許可する設定です。

#### 1. 必要なパッケージのインストール
Docker がインストールされていることを前提として、`localstack-cli` と Python 環境を整備します。

```bash
# Python3 と venv のインストール
sudo apt update
sudo apt install -y python3-pip python3-venv

# 作業ディレクトリの作成と仮想環境の構築
mkdir -p ~/terraform-iac-lab
cd ~/terraform-iac-lab
python3 -m venv venv
source venv/bin/activate

# LocalStack CLI のインストール
pip install localstack
```
#### Ubuntu 側で実行する LocalStack 起動用スクリプト
```
#!/bin/bash

# Ubuntuサーバー側で実施するスクリプト。Ubuntuで実行した後はMac（クライアント）からterraformコマンドを実行する。
# 1. 作業ディレクトリへ移動
cd ~/terraform-iac-lab

# 2. 仮想環境の有効化
source venv/bin/activate

# 3. クリーンアップ
echo " Resetting LocalStack..."
localstack stop > /dev/null 2>&1

# 4. Macからのアクセスを最適化して起動（EC2/Lambdaのコンテナ実行モードを有効化）
echo "Starting LocalStack (Resetting to stable mode)..."
HOSTNAME_EXTERNAL=192.168.40.100 \
GATEWAY_LISTEN=0.0.0.0 \
EC2_VM_MANAGER=docker \
localstack start -d

# 5. 静かに待機（画面を汚さない）
echo -n " Initializing..."
source venv/bin/activate
localstack wait -t 10 > /dev/null 2>&1
echo -e "\r LocalStack is Ready!    " # \r で上書きして消去
```

### Raspberry Pi (CoreDNS)
#### ラズパイを DNS サーバーとして使用し、localstack.lab を Ubuntu の IP に解決させます。
```
# Corefile 設定
# /etc/coredns/Corefile に以下を記述します。

# .lab ドメインの設定
lab:53 {
    hosts /etc/coredns/lab.hosts {
        # 自分のドメイン以外は次に渡す
        fallthrough
    }
    log
    errors
}

# それ以外の全般設定（インターネット用）
.:53 {
    forward . 8.8.8.8 8.8.4.4
    log
    errors
    cache 30
}

```
#### サービス化 (/etc/systemd/system/coredns.service)
```
[Unit]
Description=CoreDNS DNS server
After=network.target

[Service]
PermissionsStartOnly=true
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
User=nobu
ExecStart=/usr/local/bin/coredns -conf /etc/coredns/Corefile
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

