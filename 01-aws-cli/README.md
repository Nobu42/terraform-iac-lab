# 01 AWS CLI & Shell Script

このディレクトリでは、AWS CLIを使ってAWSインフラを構築する手順を学習します。

VPC、Subnet、Internet Gateway、NAT Gateway、Route Table、Security Group、EC2、ALB、RDSを順番に作成し、各リソースの依存関係と作成順序を確認します。

## 目的

- AWS CLIによるAWSリソース操作に慣れる
- インフラ構築の流れをシェルスクリプトとして整理する
- Terraformへ移行する前に、各リソースの役割と依存関係を理解する
- 作成、確認、削除まで含めた運用を意識する

## ディレクトリ構成

- `notes/`: 各ステップの解説メモ
- `scripts/`: AWS CLIを使った構築スクリプト

## 学習ステップ

1. [VPC 構築](./notes/01_vpc_setup.md)
2. [サブネット設計](./notes/02_subnet_setup.md)
3. [Internet Gateway 設定](./notes/03_internetgateway_setup.md)
4. [NAT Gateway 設定](./notes/04_nat_gateway_setup.md)
5. [Route Table 設定](./notes/05_route_table_setup.md)
6. [Security Group 設定](./notes/06_security_group_setup.md)
7. [踏み台サーバー構築](./notes/07_bastion_server_setup.md)
8. [Webサーバー構築](./notes/08_web_server_setup.md)
9. [ALB 構築](./notes/09_LoadBalancer_setup.md)
10. [RDS 構築](./notes/10_Database_setup.md)

## 関連ドキュメント

- [設計仕様書](../docs/Design_Specification.md)
- [AWS CLI コマンドメモ](../docs/aws_commands.md)
- [ネットワーク構成図](../docs/Network_Architecture.png)

## 注意事項

このディレクトリのスクリプトはAWSリソースを作成します。実行前にリージョン、認証情報、課金対象リソース、削除手順を確認してください。

秘密鍵、認証情報、`.pem` ファイルはリポジトリに含めません。

