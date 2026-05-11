# 04 Terraform

このディレクトリでは、AWS CLIとShell Scriptで構築してきたAWS Webアプリケーション基盤をTerraformへ段階的に移行します。

まずはVPC、Subnet、Internet Gateway、Route Tableなどのネットワーク基盤から始め、EC2、ALB、RDS、S3、Route 53、ElastiCache、CloudWatchへ広げていきます。

## 目的

- AWS CLIで確認した作成順序と依存関係をTerraformで再現する
- `terraform plan` で差分を確認してから反映する流れを身につける
- 手順ベースの構築を、再実行しやすいIaCへ置き換える
- 後続のAuto Scaling、ECS/Fargate、CI/CDへ進むための土台を作る

## 現在の方針

最初から全リソースをTerraform化せず、小さい単位で確認しながら進めます。

最初の対象:

```text
VPC
Public Subnet x2
Private Subnet x2
Internet Gateway
Public Route Table
Public Route Table Association
```

現在は、EC2とALBまで追加し、ALB DNS名へHTTPアクセスできるところまで確認しています。

Web EC2上のアプリケーションは未構築のため、Target Group Health Checkは `unhealthy`、ALBの応答は `502 Bad Gateway` になることを確認済みです。

RDS、ElastiCacheなどの課金が大きいリソースは、小さい単位で `plan` / `apply` / `destroy` を確認しながら追加します。

## フォルダ構成

```text
04-terraform/
  README.md
  notes/
    00_terraform_plan.md
    01_vpc.md
    02_nat_gateway.md
    03_security_group.md
    04_ec2.md
    05_ec2_alb.md
    06_rds.md
    07_s3.md
    08_route53_acm.md
    09_elasticache.md
    10_cloudwatch.md
  envs/
    dev/
      versions.tf
      provider.tf
      variables.tf
      locals.tf
      main.tf
      outputs.tf
      terraform.tfvars.example
  modules/
```

最初は `envs/dev` に素直に書き、構成が一通り動いてから `modules/` への切り出しを検討します。

## Notes

Terraform化の全体計画は以下に整理しています。

- [Terraform化計画](./notes/00_terraform_plan.md)
- [VPC / Subnet / Internet Gateway / Public Route Table](./notes/01_vpc.md)
- [NAT Gateway / Private Route Table](./notes/02_nat_gateway.md)
- [Security Group](./notes/03_security_group.md)
- [EC2 Preparation](./notes/04_ec2.md)
- [EC2 / ALB](./notes/05_ec2_alb.md)

## 初回作成ファイル

次に作成するファイル:

```text
04-terraform/envs/dev/versions.tf
04-terraform/envs/dev/provider.tf
04-terraform/envs/dev/variables.tf
04-terraform/envs/dev/locals.tf
04-terraform/envs/dev/main.tf
04-terraform/envs/dev/outputs.tf
04-terraform/envs/dev/terraform.tfvars.example
```

初回はlocal backendで開始します。S3 backendやstate lockは、基本操作に慣れてから追加します。

## 基本コマンド

Terraform作業は `envs/dev` で実行します。

```bash
cd /Users/nobu/terraform-iac-lab/04-terraform/envs/dev
```

初期化:

```bash
terraform init
```

フォーマット:

```bash
terraform fmt
```

構文チェック:

```bash
terraform validate
```

差分確認:

```bash
terraform plan
```

作成:

```bash
terraform apply
```

削除:

```bash
terraform destroy
```

## 注意点

- `terraform plan` を読んでから `apply` する
- Terraformで作ったリソースは基本的にTerraformで削除する
- AWS CLIでTerraform管理リソースを削除するとstateとの差分が発生する
- `terraform.tfvars`、`.terraform/`、`terraform.tfstate` はGitに入れない
- DBパスワード、SMTPパスワード、秘密鍵などの秘密情報はGitに入れない
- NAT Gateway、ALB、RDS、ElastiCacheは課金対象のため、確認後は削除する

## 既存リソースの扱い

以下は既に作成済みで、日次削除しないため、最初はTerraform管理に入れません。

- ドメイン登録
- Public Hosted Zone本体
- ACM証明書本体
- ACM DNS検証用CNAME
- SES Domain Identity
- SES DKIM / SPF / DMARC
- SES SMTP IAM User

必要になったらdata sourceで参照し、後続で `terraform import` を検討します。
