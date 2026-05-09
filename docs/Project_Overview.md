# Project Overview

このドキュメントでは、`terraform-iac-lab` の学習方針、参考資料、扱っているAWS構成、確認観点を整理します。

ルートREADMEはリポジトリ全体の入口として簡潔にし、詳細な背景や一覧情報はこのドキュメントにまとめます。

## 参考資料と本リポジトリの位置づけ

本リポジトリのAWS基本構成は、以下の書籍を参考にしています。

- 書籍名: `AWSではじめるインフラ構築入門 第2版`
- 著者: `中垣 健志`
- 出版社: `株式会社 翔泳社`
- ISBN: `978-4-7981-8016-8`

参考書籍では、AWSマネジメントコンソールを使って、VPC、Subnet、EC2、ALB、RDSなどをGUI操作で構築しています。

本リポジトリでは、その構成を題材として、GUI操作ではなくAWS CLIとShell Scriptで再構成しました。

各リソースの作成順序、依存関係、削除順序を理解するために、構築スクリプト、確認スクリプト、削除スクリプト、コスト確認スクリプトを作成しています。

さらに、Amazon Linux 2023での差分対応、Route 53 Public / Private DNS、ACM、SES、ElastiCache、AnsibleによるRailsデプロイ、CloudWatch監視、Terraform化、Auto Scaling、ECS/Fargate、CI/CDへ学習範囲を広げていく予定です。

そのため、本リポジトリは書籍内容の単純な写経ではなく、GUIベースの構築手順をコード化し、運用と自動化の観点を加えて再構成した学習用ポートフォリオです。

## 学習方針

このリポジトリでは、いきなりTerraformから始めず、まずAWS CLIで各リソースの作成順序と依存関係を確認します。

1. AWS CLIでリソースの作成手順を確認する
2. Shell Scriptで構築手順を整理する
3. AnsibleでEC2内部の設定とRailsアプリケーションのデプロイを行う
4. CloudWatch Logs、メトリクス、アラーム、ダッシュボードを設定する
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
- CloudWatch Logs
- CloudWatch Alarm
- CloudWatch Dashboard
- Terraform化計画
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
- CloudWatch Alarm / Dashboardによる基本的な監視構成
- タグ、コスト確認、構築確認、削除手順を含めた基本的な運用
- Terraform化する際に必要になるリソース間の依存関係
- 構築中に発生したエラーの原因調査と再発防止

