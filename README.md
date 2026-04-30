# AWS Infrastructure Learning Lab
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)

AWS CLIによる手動構築手順をシェルスクリプト化し、その構成をTerraformへ移行することで、AWSリソースの依存関係とIaCのメリットを学習するためのポートフォリオです。
このリポジトリでは、まずAWS CLIでVPC、Subnet、Route Table、EC2、ALBなどを順番に構築し、次に同等の構成をTerraformで再現します。今後はAnsibleを用いて、EC2内部のユーザー作成、パッケージ導入、アプリケーション設定の自動化も追加予定です。

## このリポジトリで示したいこと

- AWS CLIで各リソースの作成順序と依存関係を理解していること
- Shell Scriptで構築手順を自動化できること
- Terraformで同等構成を再現し、差分管理できること
- コスト、タグ、削除手順を意識して運用していること
- 今後Ansibleでサーバー内部構成の自動化まで拡張すること

##  Network Architecture

このラボの論理構成図です。詳細なパラメータ設定については[設計仕様書](./docs/Design_Specification.md)を参照してください。

![Network Architecture](./docs/Network_Architecture.png?v=2)

## 01 AWS CLI


## 02 Terraform
