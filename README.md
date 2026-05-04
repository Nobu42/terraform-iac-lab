# AWS Infrastructure Learning Lab

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-%231A1918.svg?style=for-the-badge&logo=ansible&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-%232496ED.svg?style=for-the-badge&logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-%23326CE5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)

AWS上にWebアプリケーション基盤を構築し、構築手順、依存関係、運用、削除までを確認するための学習用リポジトリです。

まずAWS CLIとシェルスクリプトで、VPC、Subnet、Route Table、Security Group、EC2、ALB、RDS、S3、Route 53、ACM、SES、ElastiCacheを順番に構築します。
その後、EC2上へのRailsアプリケーションデプロイ、CloudWatchによる監視、Terraform化、Auto Scaling、ECS/Fargate、CI/CDへ広げていく予定です。

## 学習方針

このリポジトリでは、いきなりTerraformから始めず、まずAWS CLIで各リソースの作成順序と依存関係を確認します。

1. AWS CLIでリソースの作成手順を確認する
2. Shell Scriptで構築手順を整理する
3. AnsibleでEC2内部の設定とRailsアプリケーションのデプロイを行う
4. CloudWatch Logs、メトリクス、アラームを設定する
5. Terraformで同じ構成をコード化する
6. Auto Scaling Groupを追加する
7. ECS/FargateでWebアプリケーションを動かす
8. CodePipelineまたはGitHub Actionsでデプロイ手順を作る

## 現在扱っている構成

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
- RDS for MySQL
- S3
- IAM Role / Instance Profile
- Route 53 Public Hosted Zone
- Route 53 Private Hosted Zone
- ACM Certificate
- SES Domain Identity
- SES SMTP送信
- SESメール受信
- ElastiCache for Redis
- 削除スクリプト
- 構築確認スクリプト
- コスト確認スクリプト

## このリポジトリで確認すること

- AWS CLIでリソースを作成する順序
- VPC、Subnet、Route Table、Security Groupの関係
- Public SubnetとPrivate Subnetの使い分け
- 踏み台サーバー経由のSSH接続
- ALBからPrivate Subnet上のWebサーバーへ通信する構成
- RDSをPrivate Subnetから利用する構成
- S3をEC2のIAM Roleから利用する構成
- Route 53でPublic DNS / Private DNSを管理する構成
- ACM証明書を使ったHTTPS化
- SESによるメール送信とメール受信
- ElastiCache for RedisをPrivate Subnetで利用する構成
- タグ、コスト確認、構築確認、削除手順を含めた基本的な運用
- Terraform化する際に必要になるリソース間の依存関係
- 構築中に発生したエラーの原因調査と再発防止

## Network Architecture

このラボの論理構成図です。詳細なパラメータ設定については[設計仕様書](./docs/Design_Specification.md)を参照してください。

![Network Architecture](./docs/Network_Architecture.png?v=4)

## 01 AWS CLI

AWS CLIで各AWSリソースを順番に作成し、ネットワーク、サーバー、ロードバランサー、データベース、ストレージ、DNS、証明書、メール、キャッシュの構成を確認します。

- [AWS CLI編 README](./01-aws-cli/README.md)
- [初期設定](./01-aws-cli/notes/00_aws_cli_initial_setup.md)
- [解説メモ](./01-aws-cli/notes)
- [シェルスクリプト](./01-aws-cli/scripts)
- [設計仕様書](./docs/Design_Specification.md)
- [保守運用計画書](./docs/Operation_Design.md)
- [トラブルシューティング](./docs/Troubleshooting.md)

## 02 Ansible

Ansibleを使って、EC2内部のパッケージ導入、設定ファイル配置、Railsアプリケーションのデプロイを管理します。

MacからAnsibleを実行し、踏み台サーバー経由でPrivate Subnet上のWebサーバー `web01` / `web02` に接続します。現在はInventoryの作成とAnsible pingによる疎通確認まで完了しています。

- [Ansible編 README](./02-ansible/README.md)
- [Inventory](./02-ansible/inventory/hosts.ini)
- [Playbooks](./02-ansible/playbooks)

今後は、共通パッケージの導入、Ruby/Rails実行環境の構築、Puma/systemd設定、RDS・S3・SES・ElastiCache連携を追加していきます。


## 03 CloudWatch

CloudWatch Logs、メトリクス、アラームを設定します。

EC2、ALB、Target Group、RDS、ElastiCacheの状態を監視し、運用保守で確認すべき項目を整理します。

> 作成予定

## 04 Terraform

AWS CLIで作成した構成をTerraformで再現します。

手作業に近い構築手順を、再実行しやすいコードへ置き換えることを目的とします。
VPC、Subnet、Route Table、Security Group、EC2、ALB、RDS、S3、Route 53、ACM、SES、ElastiCacheを順番にTerraform化します。

> 作成予定

## 05 Auto Scaling

現在のWeb EC2構成をもとに、Launch TemplateとAuto Scaling Groupを追加します。

ALBのTarget GroupへAuto Scaling Groupを関連付け、Private Subnet上のWebサーバーを自動的に増減できる構成を確認します。

> 作成予定

## 06 ECS / Fargate

WebアプリケーションをDocker化し、ECS/Fargate上で動かします。

ECR、ECS Cluster、Task Definition、Service、ALB連携を扱う予定です。

> 作成予定

## 07 CI/CD

CodePipeline、CodeBuild、CodeDeploy、またはGitHub Actionsを使ってデプロイ手順を作成します。

アプリケーションの変更を安全に反映する流れを確認します。

> 作成予定

