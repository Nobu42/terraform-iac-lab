# AWS Infrastructure Learning Lab

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-%231A1918.svg?style=for-the-badge&logo=ansible&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-%23326CE5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)

AWSの基本的なWebシステム構成を題材に、構築手順と運用を段階的に学習するためのリポジトリです。

最初にAWS CLIとシェルスクリプトでVPC、Subnet、Route Table、Security Group、EC2、ALBなどを作成し、各リソースの役割と依存関係を確認します。その後、同じ構成をTerraformで再現し、AnsibleでEC2内部の設定を自動化します。さらに、WebアプリケーションをDocker化し、Kubernetesでのデプロイやネットワーク構成も検証する予定です。

## 学習方針

このリポジトリでは、同じ構成を以下の順番で扱います。

1. AWS CLIで手順を確認する
2. Shell Scriptで構築手順を整理する
3. Terraformでインフラ構成をコード化する
4. Ansibleでサーバー内部の設定を自動化する
5. Dockerでアプリケーション実行環境をまとめる
6. Kubernetesでデプロイ、Service、Ingressを検証する

## 扱う構成

- VPC
- Public Subnet / Private Subnet
- Internet Gateway
- NAT Gateway
- Route Table
- Security Group
- Bastion EC2
- Web EC2
- Application Load Balancer
- Target Group / Listener

## このリポジトリで確認すること

- AWS CLIでリソースを作成する順序
- VPC、Subnet、Route Table、Security Groupの関係
- Public SubnetとPrivate Subnetの使い分け
- 踏み台サーバー経由のSSH接続
- ALBからPrivate Subnet上のWebサーバーへ通信する構成
- Terraformによる再現性と差分確認
- AnsibleによるOS設定、パッケージ導入、アプリケーション配置
- Dockerによるアプリケーション実行環境の整理
- KubernetesのService、Ingress、ロードバランサー連携
- タグ、コスト、削除手順を含めた基本的な運用

## Network Architecture

このラボの論理構成図です。詳細なパラメータ設定については[設計仕様書](./docs/Design_Specification.md)を参照してください。

![Network Architecture](./docs/Network_Architecture.png?v=2)

## 01 AWS CLI

AWS CLIで各AWSリソースを順番に作成し、ネットワーク、EC2、ALBの依存関係を確認します。

- [初期設定](./01-aws-cli/notes/00_aws_cli_initial_setup.md)
- [AWS CLI編 README](./01-aws-cli/README.md)
- [解説メモ](./01-aws-cli/notes)
- [シェルスクリプト](./01-aws-cli/scripts)
- [設計仕様書](./docs/Design_Specification.md)
- [保守運用計画書](./docs/Operation_Design.md)

## 02 Terraform

AWS CLIで作成した構成をTerraformで再現します。
手作業に近い構築手順を、再実行しやすいコードへ置き換えることを目的とします。

> 作成中

## 03 Ansible

EC2内部のユーザー作成、パッケージ導入、アプリケーション設定をAnsibleで管理します。
踏み台サーバー経由でPrivate Subnet上のWebサーバーへ接続する構成も扱います。

> 作成中

## 04 Docker

Webアプリケーションの実行環境をDockerでまとめます。
EC2上でのコンテナ実行、ポート公開、ログ確認を扱う予定です。

> 作成中

## 05 Kubernetes

Docker化したアプリケーションをKubernetes上で動かします。
Deployment、Service、Ingress、ロードバランサー連携を確認する予定です。

> 作成中

