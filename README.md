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

## 参考資料と本リポジトリの位置づけ

本リポジトリのAWS基本構成は、以下の書籍を参考にしています。

- 書籍名: `AWSではじめるインフラ構築入門 第2版`
- 著者: `中垣 健志`
- 出版社: `株式会社 翔泳社`
- ISBN: `978-4-7981-8016-8`

参考書籍では、AWSマネジメントコンソールを使って、VPC、Subnet、EC2、ALB、RDSなどをGUI操作で構築しています。

本リポジトリでは、その構成を題材として、GUI操作ではなくAWS CLIとShell Scriptで再構成しました。
各リソースの作成順序、依存関係、削除順序を理解するために、構築スクリプト、確認スクリプト、削除スクリプト、コスト確認スクリプトを作成しています。

さらに、Amazon Linux 2023での差分対応、Route 53 Public / Private DNS、ACM、SES、ElastiCache、AnsibleによるRailsデプロイ、Terraform化、CloudWatch監視、Auto Scaling、ECS/Fargate、CI/CDへ学習範囲を広げていく予定です。

そのため、本リポジトリは書籍内容の単純な写経ではなく、GUIベースの構築手順をコード化し、運用と自動化の観点を加えて再構成した学習用ポートフォリオです。

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
- AnsibleによるRails 7.2アプリケーションデプロイ
- Puma / nginx / systemd
- Rails Active StorageによるS3画像保存
- CloudWatch Logs設計
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
- Rails 7.2アプリケーションをPrivate Subnet上のWeb EC2へデプロイする構成
- ALB + ACM + Route 53でRailsアプリをHTTPS公開する構成
- Railsの投稿画像をActive Storage経由でS3へ保存する構成
- CloudWatch Logsでnginx / Pumaログを収集する構成
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

MacからAnsibleを実行し、踏み台サーバー経由でPrivate Subnet上のWebサーバー `web01` / `web02` に接続します。

現在はRuby 3.3.6 / Rails 7.2.3 / Puma / nginx / systemdによるRailsアプリケーションのデプロイまで確認済みです。

Railsアプリでは、ユーザー登録、ログイン、投稿、画像アップロードを実装し、投稿本文はRDS MySQL、投稿画像はActive Storage経由でS3へ保存します。

また、日次再構築時間を短縮するため、Ruby導入済みのWebベースAMIを作成し、Web EC2作成時に利用できるようにしました。

- [Ansible編 README](./02-ansible/README.md)
- [Inventory](./02-ansible/inventory/hosts.ini)
- [Playbooks](./02-ansible/playbooks)

主な確認済み項目:

- Bastion経由のAnsible接続
- Ruby 3.3.6 / Rails 7.2.3
- nginx + Puma + systemd
- ALB + ACM + Route 53によるHTTPS公開
- RDS MySQL接続
- Active StorageによるS3画像保存
- web01 / web02 2台構成での `SECRET_KEY_BASE` 共有
- AnsibleまとめPlaybook `site.yml`

## 03 CloudWatch

CloudWatch Logs、メトリクス、アラームを設定します。

まずはEC2上のnginx / PumaログをCloudWatch Logsへ集約し、Railsアプリケーションの動作確認やトラブル調査に利用できる状態を目指します。

その後、EC2、ALB、Target Group、RDS、ElastiCacheのメトリクス監視、アラーム、ダッシュボードへ拡張します。

- [CloudWatch編 README](./03-cloudwatch/README.md)
- [CloudWatch Logs設計メモ](./03-cloudwatch/notes/01_cloudwatch_logs_setup.md)

収集予定ログ:

- `/var/log/nginx/access.log`
- `/var/log/nginx/error.log`
- `/var/www/nobu-iac-lab/log/puma.stdout.log`
- `/var/www/nobu-iac-lab/log/puma.stderr.log`

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
