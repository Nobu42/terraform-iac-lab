# Terraform IaC Lab

![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Raspberry Pi](https://img.shields.io/badge/-Raspberry%20Pi-C51A4A?style=for-the-badge&logo=Raspberry-Pi)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E9430F?style=for-the-badge&logo=ubuntu&logoColor=white)

MacBook Air (M4) と自宅の Raspberry Pi 4（CoreDNS）、Ubuntu サーバーを連携させ、AWS クラウドインフラをシミュレートする IaC（Infrastructure as Code）学習環境。
SAA（Solutions Architect Associate）取得後の知識をアウトプットし、実務レベルの構築スキルを定着させることを目的としています。

Terraform、Ansible、Kubernetes も順次追加予定。

## 1. Learning AWS (AWS CLI & Shell Script)

`learning_aws/` ディレクトリにて、シェルスクリプトによる AWS 構成管理を実践。
* **[00] [編集環境]**
    * **[vimrc](./dotfiles/vimrc)**
    * **[bashrc](./dotfiles/bashrc)**
    * **[Install_Setup](./dotfiles/Install_Setup.md)**

* **[01] [VPC 構築](./learning_aws/01_vpc_setup.md)** - ネットワークの土台
* **[02] [サブネット設計](./learning_aws/02_subnet_setup.md)** - Public/Private の切り分け
* **[03] [IGW 設定](./learning_aws/03_internetgateway_setup.md)** - 外の世界への出口
* **[04] [NAT Gateway](./learning_aws/04_nat_gateway_setup.md)** - プライベート空間からの通信確保
* **[05] [ルートテーブル](./learning_aws/05_route_table_setup.md)** - パケットの通り道を定義
* **[06] [セキュリティグループ](./learning_aws/06_security_group_setup.md)** - 仮想ファイアウォール
* **[07] [踏み台サーバー](./learning_aws/07_bastion_server_setup.md)** - セキュアな SSH 入口
* **[08] [Web サーバー (EC2)](./learning_aws/08_web_server_setup.md)** - 内部サーバー構築と多段 SSH
* **[09] [ロードバランサー (ALB)](./learning_aws/09_LoadBalancer_setup.md)** - サービス公開と負荷分散
* **[10] [データベース (RDS)](./learning_aws/10_Database_setup.md)** - マルチAZによるデータ冗長化

> **一括構築:** [`./learning_aws/All_Setup.sh`](./learning_aws/All_Setup.sh) を実行することで、全工程を自動で再現可能です。

---

### コンセプト：ハイブリッド・ラボ

- **柔軟なエンドポイント:** 外出先の Mac (M4) と自宅の Ubuntu (192.168.40.100) を自動判別し、LocalStack への接続先を動的に切り替え。

- **自宅DNS連携:** Raspberry Pi 4 (CoreDNS) により、localstack.lab などの独自ドメインで AWS シミュレーション環境を運用。

### Network Topology (Physical)

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
## LocalStack Logical Architecture (VPC)
```
[ VPC: sample-vpc (10.0.0.0/16) ]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          │
          │ ┌────────────────────────────────────────┐
          └─┤ [ Internet Gateway ] <───> ( User )    │
            └──────────────────┬─────────────────────┘
                               │
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      [ AZ-1a ]                │                [ AZ-1c ]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ┌────────────────────────┐   │   ┌────────────────────────┐
  │ [ Public Subnets ]     │   │   │                        │
  │ [ ALB ロードバランサ　     │───┼───│[ Bastion 踏み台サーバ]    │
  │  [ NAT Gateway 01 ]    │       │  [ NAT Gateway 02 ]    │
  └──────────┬─────────────┘       └──────────┬─────────────┘
             ▼                                ▼
  ┌──────────┴─────────────┐       ┌──────────┴─────────────┐
  │ [ Private Subnets ]    │       │                        │
  │   [ WebServer 01 ]   <───振分───> [ WebServer 02 ]       │
  └──────────┬─────────────┘       └──────────┬─────────────┘
             │                                │
━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┿━━━━━━━━━━━━━━━━━━━━━━━
             ▼                                ▼
  ┌──────────┴─────────────┐       ┌──────────┴─────────────┐
  │ [ DB Subnets ]         │       │ [ DB Subnets ]         │
  │   [ DB Master ]        <──同期──>  [ DB Standby ]        │
  └────────────────────────┘       └────────────────────────┘
```
![Physical](./docs/Physical.png?v=2)
![Network Architecture](./docs/Network_Architecture.png?v=2)


## Learning Terraform

- **追記予定**


