# terraform-iac-lab

# Terraform IaC Lab

このリポジトリは、MacBook Pro (M3) 上で AWS クラウドインフラをシミュレートし、Terraform を用いた Infrastructure as Code (IaC) の学習と実験を行うためのプライベートラボです。

##  コンセプト
- **ローカル完結:** LocalStack を使用し、AWS 料金を気にせず実験できる環境。
- **ハイブリッド設計:** 自宅の Ubuntu サーバー (LocalStack 稼働) と外出先の Mac 単体を自動で判別するスマートな設定。
- **プロフェッショナルな編集環境:** Linux カーネル開発の流儀を取り入れた Vim 設定。

## 🛠 インストールとセットアップ（Mac）

### 1. 必須ツールの導入
Homebrew を使用して、必要なパッケージをインストールします。

```bash
# Terraform のインストール
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# AWS CLI のインストール
brew install awscli

# LocalStack CLI (オプション)
brew install localstack/tap/localstack-cli
