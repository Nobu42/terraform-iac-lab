# 01 AWS CLI & Shell Script

このディレクトリでは、AWS CLIとシェルスクリプトを使って、AWS上にWebアプリケーション基盤を段階的に構築します。

VPC、Subnet、Route Table、Security Group、EC2、ALB、RDS、S3、Route 53、ACM、SES、ElastiCacheを順番に作成し、各AWSリソースの役割、依存関係、確認方法、削除方法を整理します。

## 目的

- AWS CLIによるAWSリソース操作に慣れる
- AWSリソースの作成順序と依存関係を理解する
- シェルスクリプトで構築手順を再実行しやすく整理する
- Public Subnet / Private Subnetを使った基本的なWebシステム構成を理解する
- ALB、RDS、S3、DNS、HTTPS、メール、キャッシュを含む構成を確認する
- 作成、動作確認、コスト確認、削除まで含めた運用を意識する
- 後続のAnsible、Terraform、Auto Scaling、ECS/Fargate、CloudWatch、CI/CDへつなげる

## ディレクトリ構成

- `notes/`: 各ステップの解説メモ
- `scripts/`: AWS CLIを使った構築、確認、削除スクリプト

## 学習ステップ

0. [初期設定](./notes/00_aws_cli_initial_setup.md)
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
11. [S3 構築](./notes/11_s3_setup.md)
12. [Public DNS 構築](./notes/12_public_dns_setup.md)
13. [Public DNS 名前解決のパケットキャプチャ](./notes/13_public_dns_packet_capture.md)
14. [Private DNS 構築](./notes/14_private_dns_setup.md)
15. [ACM 証明書とHTTPS Listener設定](./notes/15_acm_certificate_setup.md)
16. [SES 送信用ドメイン設定](./notes/16_ses_setup.md)
17. [SES SMTP送信テスト](./notes/17_sendmail_test.md)
18. [SES メール受信設定](./notes/18_ses_receiving_setup.md)
19. [ElastiCache Redis 構築](./notes/19_elasticache_setup.md)

## 主な構成

- VPC: `sample-vpc`
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

## 主なスクリプト

構築用:

```text
01_vpc_setup.sh
02_subnet_setup.sh
03_internetgateway_setup.sh
04_nat_gateway_setup.sh
05_route_table_setup.sh
06_security_group_setup.sh
07_bastion_server_setup.sh
08_Web_server_setup.sh
09_LoadBalancer_setup.sh
10_Database_setup.sh
11_s3_setup.sh
12_public_dns_setup.sh
14_private_dns_setup.sh
15_acm_certificate_setup.sh
16_ses_setup.sh
18_ses_receiving_setup.sh
19_elasticache_setup.sh
```

確認・運用用:

```text
All_Setup.sh
check_setup.sh
check_cleanup.sh
check_cost.sh
cleanup_all.sh
status.sh
ec2_status.sh
ssh_port.sh
```

テスト用:

```text
17_sendmail_test.py
```

## 実行順序

基本構成を作成する場合は、以下の順番で実行します。

```bash
./01_vpc_setup.sh
./02_subnet_setup.sh
./03_internetgateway_setup.sh
./04_nat_gateway_setup.sh
./05_route_table_setup.sh
./06_security_group_setup.sh
./07_bastion_server_setup.sh
./08_Web_server_setup.sh
./09_LoadBalancer_setup.sh
./10_Database_setup.sh
./11_s3_setup.sh
./12_public_dns_setup.sh
./14_private_dns_setup.sh
./15_acm_certificate_setup.sh
./19_elasticache_setup.sh
```

まとめて実行する場合は、`All_Setup.sh` を利用します。

```bash
./All_Setup.sh
```

## 毎回実行しないスクリプト

以下は初回設定、または必要な時だけ実行します。

| スクリプト | 実行タイミング |
| :--- | :--- |
| `16_ses_setup.sh` | SESのドメイン認証、DKIM、SPF、DMARCを初期設定する時 |
| `17_sendmail_test.py` | SES SMTPで送信テストする時 |
| `18_ses_receiving_setup.sh` | SESでメール受信テストを行う時 |
| `cleanup_all.sh` | 学習後に課金対象リソースを削除する時 |
| `check_cost.sh` | 月初から現在までの利用料金を確認する時 |
| `check_setup.sh` | 構築後に主要リソースの状態を確認する時 |
| `check_cleanup.sh` | 削除後にリソースが残っていないか確認する時 |

## 構築後の確認

構築後は以下を確認します。

```bash
./check_setup.sh
```

主な確認項目:

- VPC、Subnet、Route Tableが作成されていること
- NAT Gatewayが `available` であること
- EC2が `running` であること
- ALBが `active` であること
- Target GroupのTarget Healthが `healthy` であること
- RDSが `available` であること
- Public DNS / Private DNS が作成されていること
- ACM証明書が `ISSUED` であること
- SES Identityが認証済みであること
- ElastiCache Replication Groupが `available` であること

## 削除

学習後は課金を抑えるため、削除スクリプトを実行します。

```bash
./cleanup_all.sh
```

削除後は以下で確認します。

```bash
./check_cleanup.sh
```

削除スクリプトでは、日々の学習で作成する課金対象リソースを削除します。

一方で、以下は継続利用するため残します。

- ドメイン登録
- Route 53 Public Hosted Zone
- ACM証明書
- ACM検証用CNAME
- SES Domain Identity
- SES DKIM / SPF / DMARC レコード
- SES SMTP用IAMユーザー

## 注意事項

このディレクトリのスクリプトは実AWSにリソースを作成します。実行前にリージョン、プロファイル、課金対象リソース、削除手順を確認してください。

特にNAT Gateway、ALB、RDS、ElastiCacheは起動時間に応じて料金が発生します。学習が終わったら `cleanup_all.sh` を実行します。

秘密鍵、認証情報、SMTPパスワード、`.pem` ファイルはリポジトリに含めません。

## 関連ドキュメント

- [設計仕様書](../docs/Design_Specification.md)
- [保守・運用計画](../docs/Operation_Design.md)
- [AWS CLI コマンドメモ](../docs/aws_commands.md)
- [ネットワーク構成図](../docs/Network_Architecture.png)

