# Terraform化計画

このメモでは、AWS CLIとShell Scriptで構築してきたAWS Webアプリケーション基盤を、Terraformへ段階的に移行する方針を整理する。

いきなり全リソースをTerraform化するのではなく、AWS CLIで確認した作成順序と依存関係をもとに、小さい単位で `terraform plan` / `terraform apply` / `terraform destroy` を確認しながら進める。

## 目的

- AWS CLIで理解したリソース作成順序をTerraformへ置き換える
- 手順ベースの構築を、再実行しやすいIaCへ整理する
- `plan` で差分を確認してから反映する流れに慣れる
- 既存の設計書、AWS CLIスクリプト、Ansible、CloudWatchの内容をTerraform構成へつなげる
- 後続のAuto Scaling、ECS/Fargate、CI/CDへ進むための土台を作る

## 前提

Terraform化の元になる構成は、以下で定義、実装済みの内容を基準にする。

```text
docs/Design_Specification.md
01-aws-cli/scripts/*.sh
02-ansible/playbooks/*.yml
03-cloudwatch/scripts/*.sh
```

AWS CLI編では、以下の順番でリソースを作成している。

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
19_elasticache_setup.sh
```

Terraform化でも、この依存関係を基本にする。

## ディレクトリ方針

最初は理解を優先し、`envs/dev` に素直に書く。

モジュール化は、VPC、EC2、ALB、RDSなどの構成が一通り動いてから検討する。

```text
04-terraform/
  README.md
  notes/
    00_terraform_plan.md
    01_vpc.md
    02_subnet.md
    03_internet_gateway.md
    04_nat_gateway.md
    05_route_table.md
    06_security_group.md
    07_ec2.md
    08_alb.md
    09_rds.md
    10_s3.md
    11_route53_acm.md
    12_elasticache.md
    13_cloudwatch.md
  envs/
    dev/
      provider.tf
      versions.tf
      variables.tf
      locals.tf
      main.tf
      outputs.tf
      terraform.tfvars.example
  modules/
```

## 命名・タグ方針

AWS CLI編と同じNameタグ、Projectタグ、Environmentタグを使う。

```text
Project     = terraform-iac-lab
Environment = learning
```

共通タグは `locals.tf` にまとめる予定。

例:

```hcl
locals {
  common_tags = {
    Project     = "terraform-iac-lab"
    Environment = "learning"
  }
}
```

各リソースでは、`Name` だけ個別に追加する。

```hcl
tags = merge(local.common_tags, {
  Name = "sample-vpc"
})
```

## 管理対象の方針

### Terraformで作成するもの

日次学習時に作成、削除する課金対象リソースを中心にTerraform管理へ移す。

- VPC
- Subnet
- Internet Gateway
- NAT Gateway
- Elastic IP
- Route Table
- Security Group
- EC2
- ALB
- Target Group
- Listener
- RDS
- S3
- IAM Role / Instance Profile
- Private Hosted Zone
- Public DNS一時レコード
- ElastiCache
- CloudWatch Alarm
- CloudWatch Dashboard

### すぐにはTerraform管理しないもの

既に作成済みで、日次削除しないリソースは、最初はTerraform管理に入れない。

- ドメイン登録
- Public Hosted Zone本体
- ACM証明書本体
- ACM DNS検証用CNAME
- SES Domain Identity
- SES DKIM / SPF / DMARC
- SES SMTP IAM User

これらは既存リソースとして参照するか、後続で `terraform import` を検討する。

## 主要パラメータ

### Provider

| 項目 | 値 |
| :--- | :--- |
| AWS Profile | learning |
| Region | ap-northeast-1 |

### VPC

| 項目 | 値 |
| :--- | :--- |
| Name | sample-vpc |
| CIDR | 10.0.0.0/16 |
| DNS Hostnames | true |
| DNS Support | true |

### Subnet

| 種別 | Name | AZ | CIDR | Public IP自動割当 |
| :--- | :--- | :--- | :--- | :--- |
| Public | sample-subnet-public01 | ap-northeast-1a | 10.0.0.0/20 | true |
| Public | sample-subnet-public02 | ap-northeast-1c | 10.0.16.0/20 | true |
| Private | sample-subnet-private01 | ap-northeast-1a | 10.0.64.0/20 | false |
| Private | sample-subnet-private02 | ap-northeast-1c | 10.0.80.0/20 | false |

### Internet Gateway / NAT Gateway

| リソース | Name | 配置 |
| :--- | :--- | :--- |
| Internet Gateway | sample-igw | sample-vpc |
| NAT Gateway | sample-ngw-01 | sample-subnet-public01 |
| NAT Gateway | sample-ngw-02 | sample-subnet-public02 |

NAT Gatewayは課金が大きいため、最初のTerraform練習では後回しにする。

まずはVPC、Subnet、Internet Gateway、Public Route Tableまでを確認し、その後NAT Gatewayを追加する。

### Route Table

| Name | 対象 | Route | 関連Subnet |
| :--- | :--- | :--- | :--- |
| sample-rt-public | Public | 0.0.0.0/0 -> sample-igw | public01, public02 |
| sample-rt-private01 | Private | 0.0.0.0/0 -> sample-ngw-01 | private01 |
| sample-rt-private02 | Private | 0.0.0.0/0 -> sample-ngw-02 | private02 |

### Security Group

| Name | 用途 | Inbound |
| :--- | :--- | :--- |
| sample-sg-bastion | Bastion | SSH 22 from my global IP /32 |
| sample-sg-elb | ALB | HTTP 80 from 0.0.0.0/0, HTTPS 443 from 0.0.0.0/0 |
| sample-sg-web | Web | SSH 22 from sample-sg-bastion, App 3000 from sample-sg-elb |
| sample-sg-db | RDS | MySQL 3306 from sample-sg-web |
| sample-sg-elasticache | ElastiCache | Redis 6379 from sample-sg-web |

Bastionの接続元IPは実行環境で変わるため、Terraformでは変数 `my_global_ip_cidr` として渡す。

例:

```hcl
my_global_ip_cidr = "203.0.113.10/32"
```

### EC2

| Name | Subnet | Instance Type | Public IP | 用途 |
| :--- | :--- | :--- | :--- | :--- |
| sample-ec2-bastion | sample-subnet-public01 | t3.micro | true | Bastion |
| sample-ec2-web01 | sample-subnet-private01 | t3.small | false | Web/AP |
| sample-ec2-web02 | sample-subnet-private02 | t3.small | false | Web/AP |

AMI方針:

- BastionはAmazon Linux 2023 latest AMIをSSM Parameter Storeから取得する
- Web EC2は当面カスタムAMI `ami-00f86224c38cc3b8c` を使う
- 将来的にはWeb AMI作成もTerraform外の手順またはPacker化を検討する

Key Pair:

```text
nobu
```

### ALB

| 項目 | 値 |
| :--- | :--- |
| ALB Name | sample-elb |
| Scheme | internet-facing |
| Type | application |
| Subnets | public01, public02 |
| Security Group | sample-sg-elb |

Target Group:

| 項目 | 値 |
| :--- | :--- |
| Name | sample-tg |
| Protocol | HTTP |
| Port | 3000 |
| Target Type | instance |
| Health Check Path | / |

Listener:

| Protocol | Port | Action |
| :--- | :--- | :--- |
| HTTP | 80 | forward -> sample-tg |
| HTTPS | 443 | forward -> sample-tg |

HTTPS Listenerでは、既存ACM証明書をdata sourceで参照する。

### RDS

| 項目 | 値 |
| :--- | :--- |
| Identifier | sample-db |
| Engine | mysql |
| Engine Version | 8.0 |
| Instance Class | db.t3.micro |
| Port | 3306 |
| Publicly Accessible | false |
| Multi-AZ | false |
| Backup Retention | 0 |
| DB Subnet Group | sample-db-subnet |
| Parameter Group | sample-db-pg |
| Option Group | sample-db-og |

DBパスワードはGitに入れない。

Terraformでは `terraform.tfvars` または環境変数 `TF_VAR_db_master_password` で渡す。

```bash
export TF_VAR_db_master_password='...'
```

### S3 / IAM

S3:

| 用途 | Bucket |
| :--- | :--- |
| Rails Active Storage | nobu-terraform-iac-lab-upload |
| SES受信 | nobu-iac-lab-mailbox |

Web EC2用IAM:

| 項目 | 値 |
| :--- | :--- |
| Role | sample-role-web |
| Instance Profile | sample-role-web |
| Attached Policy | AmazonS3FullAccess |
| Attached Policy | CloudWatchAgentServerPolicy |

学習用としてAWS管理ポリシーを使っている。

後続で最小権限化を検討する。

### Route 53 / ACM

Public Hosted Zone:

```text
nobu-iac-lab.com
```

Terraformで日次作成する一時レコード:

| Record | Type | Target |
| :--- | :--- | :--- |
| bastion.nobu-iac-lab.com | A | Bastion Public IP |
| www.nobu-iac-lab.com | A Alias | ALB |

Private Hosted Zone:

```text
home
```

Private records:

| Record | Type | Target |
| :--- | :--- | :--- |
| bastion.home | A | Bastion Private IP |
| web01.home | A | Web01 Private IP |
| web02.home | A | Web02 Private IP |
| db.home | CNAME | RDS Endpoint |

ACM証明書:

```text
www.nobu-iac-lab.com
```

ACM証明書本体は既存リソースとして参照し、ALB HTTPS Listenerに設定する。

### SES

SES送信用のDomain Identity、DKIM、SPF、DMARCは初回設定済みのため、最初のTerraform化対象から外す。

SES受信は検証する日だけ作成するリソースとして、後続でTerraform化を検討する。

| リソース | 値 |
| :--- | :--- |
| Receipt Rule Set | sample-ruleset |
| Receipt Rule | sample-rule-inquiry |
| Recipient | inquiry@nobu-iac-lab.com |
| S3 Bucket | nobu-iac-lab-mailbox |
| Prefix | inbox/ |

### ElastiCache

| 項目 | 値 |
| :--- | :--- |
| Replication Group ID | sample-elasticache |
| Engine | Redis |
| Cluster Mode | enabled |
| Node Type | cache.t3.micro |
| Shards | 2 |
| Replicas per Shard | 2 |
| Total Nodes | 6 |
| Subnet Group | sample-elasticache-sg |
| Security Group | sample-sg-elasticache |
| Port | 6379 |

ElastiCacheは課金対象で構成も重いため、RDS / S3 / ALBまで確認した後に追加する。

### CloudWatch

CloudWatch LogsのAgent導入はAnsibleで行う。

Terraformでは、まず以下を対象にする。

- CloudWatch Alarm
- CloudWatch Dashboard

Log GroupをTerraformで作るかどうかは後で決める。

現在はAnsible `09_cloudwatch_agent.yml` がLog Groupを作成し、保持期間7日を設定している。

## Terraform化ステップ

### Step 0: Terraform作業ディレクトリ準備

作成するファイル:

```text
04-terraform/envs/dev/versions.tf
04-terraform/envs/dev/provider.tf
04-terraform/envs/dev/variables.tf
04-terraform/envs/dev/locals.tf
04-terraform/envs/dev/main.tf
04-terraform/envs/dev/outputs.tf
04-terraform/envs/dev/terraform.tfvars.example
```

最初はlocal backendで始める。

S3 backendやstate lockは、基本操作に慣れてから検討する。

### Step 1: Network基礎

最初に作成するもの:

- VPC
- Public Subnet x2
- Private Subnet x2
- Internet Gateway
- Public Route Table
- Public Route Table Association

ここではNAT Gatewayをまだ作らない。

確認コマンド:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform destroy
```

AWS CLI確認:

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-vpc \
  --output table
```

### Step 2: NAT Gateway / Private Route Table

追加するもの:

- Elastic IP x2
- NAT Gateway x2
- Private Route Table x2
- Private Route Table Association x2

注意:

NAT Gatewayは時間課金がある。

学習中は作成後、確認が終わったら `terraform destroy` する。

### Step 3: Security Group

追加するもの:

- sample-sg-bastion
- sample-sg-elb
- sample-sg-web
- sample-sg-db
- sample-sg-elasticache

ポイント:

- Security Group同士の参照を使う
- Bastion SSH接続元は変数で渡す
- 循環参照を避けるため、必要に応じて `aws_security_group_rule` を分ける

### Step 4: EC2

追加するもの:

- Key Pair参照
- Amazon Linux 2023 latest AMI data source
- Bastion EC2
- Web EC2 x2
- Web EC2用IAM Role / Instance Profile

ポイント:

- Web EC2はPrivate Subnetに配置する
- Web EC2にはPublic IPを付けない
- Web EC2には `sample-role-web` を付ける
- SSH確認はBastion経由で行う

### Step 5: ALB

追加するもの:

- Target Group
- Target Group Attachment x2
- ALB
- HTTP Listener
- HTTPS Listener
- ACM certificate data source

ポイント:

- ALBはPublic Subnet 2つに配置する
- Target GroupはWeb EC2の3000番へ転送する
- HTTPS Listenerは既存ACM証明書を参照する

### Step 6: RDS

追加するもの:

- DB Subnet Group
- DB Parameter Group
- DB Option Group
- RDS MySQL Instance

ポイント:

- RDSはPrivate Subnetに配置する
- Publicly Accessibleはfalse
- DBパスワードはGitに入れない
- 学習環境ではBackup Retention 0

### Step 7: S3 / IAM

追加するもの:

- Active Storage用S3 Bucket
- Public Access Block
- Ownership Controls
- IAM Role
- Instance Profile
- Managed Policy Attachment

ポイント:

- S3バケット名はグローバルで一意
- 既に同名バケットがある場合は衝突する
- Web EC2作成タイミングとの依存関係に注意する

### Step 8: Route 53 / Private DNS

追加するもの:

- Public DNS一時レコード
- Private Hosted Zone
- Private DNS records

ポイント:

- Public Hosted Zone本体は既存を参照する
- `www` はALB Alias
- `bastion` はBastion Public IP
- `db.home` はRDS EndpointへのCNAME

### Step 9: ElastiCache

追加するもの:

- Cache Subnet Group
- ElastiCache Replication Group

ポイント:

- Redis Cluster Mode enabled
- 2 shards / replicas per shard 2
- 課金があるため最後に追加する

### Step 10: CloudWatch

追加するもの:

- CloudWatch Alarm
- CloudWatch Dashboard

ポイント:

- EC2 InstanceIdやALB DimensionはTerraformリソースから参照できる
- Dashboard Bodyは `jsonencode` で作る
- Logs収集はAnsibleのCloudWatch Agent設定と役割分担する

## 初回に作る最小構成

最初のTerraform作業では、以下だけを作る。

```text
VPC
Public Subnet x2
Private Subnet x2
Internet Gateway
Public Route Table
Public Route Table Association
```

ここまでなら、NAT GatewayやEC2を作らないため課金を抑えながらTerraformの基本操作を確認できる。

## Terraformで特に意識すること

### 1. planを必ず読む

Terraformでは、`apply` の前に `plan` で作成、変更、削除の差分を確認する。

```bash
terraform plan
```

見るポイント:

- 何が作成されるか
- 何が変更されるか
- 何が削除されるか
- 想定外のリソースが含まれていないか

### 2. stateを理解する

Terraformはstateで管理対象リソースを記録する。

AWS上に同じNameタグのリソースがあっても、stateにない場合はTerraform管理外である。

既存リソースをTerraform管理に入れるには、後続で `terraform import` を使う。

### 3. 既存リソースと新規作成リソースを分ける

このラボには、日次削除するリソースと残すリソースがある。

残すリソースを無理に最初からTerraform管理に入れない。

既存参照から始め、必要になったらimportを検討する。

### 4. 課金リソースは小さく確認する

NAT Gateway、ALB、RDS、ElastiCacheは課金対象。

Terraform学習中は、以下を習慣にする。

```bash
terraform destroy
```

または既存のAWS CLI cleanupと併用する。

ただし、Terraformで作ったリソースは基本的にTerraformで削除する。

AWS CLIで削除するとstateとの差分が発生する。

### 5. 秘密情報をGitに入れない

以下はGit管理しない。

- DB master password
- SMTP password
- 秘密鍵
- `terraform.tfvars`
- `.terraform/`
- `terraform.tfstate`

Gitに入れるのは `terraform.tfvars.example` までにする。

## まず次にやること

次は `envs/dev` に最小構成を作る。

作成予定:

```text
04-terraform/envs/dev/versions.tf
04-terraform/envs/dev/provider.tf
04-terraform/envs/dev/variables.tf
04-terraform/envs/dev/locals.tf
04-terraform/envs/dev/main.tf
04-terraform/envs/dev/outputs.tf
04-terraform/envs/dev/terraform.tfvars.example
```

最初に書くリソース:

```text
aws_vpc
aws_subnet
aws_internet_gateway
aws_route_table
aws_route
aws_route_table_association
```

最初のゴール:

```text
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
aws ec2 describe-vpcs で確認
terraform destroy
```
