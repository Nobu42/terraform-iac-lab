# 01 VPC / Subnet / Internet Gateway / Public Route Table

このメモでは、Terraformで最初に作成したネットワーク基盤について整理する。

対象は、AWS CLI編で以下のスクリプトが担当していた範囲の一部である。

```text
01_vpc_setup.sh
02_subnet_setup.sh
03_internetgateway_setup.sh
05_route_table_setup.sh のPublic Route Table部分
```

NAT GatewayとPrivate Route Tableは課金が発生するため、この段階ではまだ作成しない。

## この段階のゴール

Terraformで以下を作成し、`apply` と `destroy` まで確認する。

```text
VPC
Public Subnet x2
Private Subnet x2
Internet Gateway
Public Route Table
Public Route
Public Route Table Association x2
```

今回の `terraform apply` では、以下の結果を確認した。

```text
Apply complete! Resources: 10 added, 0 changed, 0 destroyed.
```

その後、`terraform destroy` で以下を確認した。

```text
Destroy complete! Resources: 10 destroyed.
```

つまり、Terraformで作成したリソースをTerraformのstateで管理し、Terraform自身で削除できることを確認した。

## 作成したTerraformファイル

この段階で利用する主なファイルは以下。

```text
04-terraform/envs/dev/
  versions.tf
  provider.tf
  variables.tf
  locals.tf
  main.tf
  outputs.tf
```

役割:

| ファイル | 役割 |
| :--- | :--- |
| `versions.tf` | Terraform本体とAWS Providerのバージョン制約 |
| `provider.tf` | AWS profile / region の指定 |
| `variables.tf` | VPC CIDR、Subnet CIDR、AZなどの入力値 |
| `locals.tf` | 共通タグなど、複数箇所で使う値 |
| `main.tf` | 実際に作成するAWSリソース |
| `outputs.tf` | 作成後に確認したいIDを表示 |

## AWS CLIとの対応

AWS CLIでは、作成したリソースIDを変数に入れて、後続コマンドへ渡していた。

例:

```bash
VPC_ID=$(aws ec2 create-vpc ...)

aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  ...
```

Terraformでは、リソース同士を参照して依存関係を表す。

例:

```hcl
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

resource "aws_subnet" "public_01" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_01_cidr
}
```

`vpc_id = aws_vpc.main.id` と書くことで、Terraformは以下を理解する。

```text
SubnetはVPCに依存している
VPCを先に作成する必要がある
destroy時はSubnetを先に削除する必要がある
```

AWS CLIでは自分で順番を意識していたが、Terraformでは参照関係から依存順序を判断できる。

## リソース一覧

今回 `main.tf` に定義したリソースは以下。

```text
aws_vpc.main
aws_subnet.public_01
aws_subnet.public_02
aws_subnet.private_01
aws_subnet.private_02
aws_internet_gateway.main
aws_route_table.public
aws_route.public_default
aws_route_table_association.public_01
aws_route_table_association.public_02
```

## VPC

AWS CLI編の設計:

| 項目 | 値 |
| :--- | :--- |
| Name | sample-vpc |
| CIDR | 10.0.0.0/16 |
| DNS Hostnames | enabled |
| DNS Support | enabled |

Terraform:

```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "sample-vpc"
  })
}
```

ポイント:

- `cidr_block` はVPC全体のプライベートIP範囲
- `enable_dns_hostnames = true` はVPC内のDNSホスト名を有効化する
- `enable_dns_support = true` はVPC内のDNS解決を有効化する
- RDS、Private Hosted Zone、EC2内部通信などでDNSを使うため、どちらも有効にする

## Subnet

AWS CLI編の設計:

| 種別 | Name | AZ | CIDR |
| :--- | :--- | :--- | :--- |
| Public | sample-subnet-public01 | ap-northeast-1a | 10.0.0.0/20 |
| Public | sample-subnet-public02 | ap-northeast-1c | 10.0.16.0/20 |
| Private | sample-subnet-private01 | ap-northeast-1a | 10.0.64.0/20 |
| Private | sample-subnet-private02 | ap-northeast-1c | 10.0.80.0/20 |

Terraformでは、Public Subnetだけ `map_public_ip_on_launch = true` を指定する。

```hcl
resource "aws_subnet" "public_01" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_01_cidr
  availability_zone       = var.availability_zone_1a
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "sample-subnet-public01"
    Type = "public"
  })
}
```

Private SubnetではPublic IP自動割り当てを有効にしない。

```hcl
resource "aws_subnet" "private_01" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_01_cidr
  availability_zone = var.availability_zone_1a

  tags = merge(local.common_tags, {
    Name = "sample-subnet-private01"
    Type = "private"
  })
}
```

ポイント:

- Public SubnetはALB、NAT Gateway、Bastionを配置する想定
- Private SubnetはWeb EC2、RDS、ElastiCacheを配置する想定
- 2つのAZに分けることで、ALBやWeb EC2の冗長構成につなげる

## Internet Gateway

AWS CLI編の設計:

| 項目 | 値 |
| :--- | :--- |
| Name | sample-igw |
| Attach先 | sample-vpc |

Terraform:

```hcl
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "sample-igw"
  })
}
```

ポイント:

- Internet GatewayはVPCをインターネットへ接続するための入口
- 作成するだけでは通信できない
- Route Tableに `0.0.0.0/0 -> Internet Gateway` のルートを追加して初めてPublic Subnetとして機能する

## Public Route Table

AWS CLI編の設計:

| 項目 | 値 |
| :--- | :--- |
| Name | sample-rt-public |
| Route | 0.0.0.0/0 -> sample-igw |
| Association | public01, public02 |

Terraform:

```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "sample-rt-public"
  })
}
```

Public Route:

```hcl
resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}
```

Public Subnetとの関連付け:

```hcl
resource "aws_route_table_association" "public_01" {
  subnet_id      = aws_subnet.public_01.id
  route_table_id = aws_route_table.public.id
}
```

ポイント:

- `aws_route_table` はルートテーブル本体
- `aws_route` はルートテーブル内の1本のルート
- `aws_route_table_association` はSubnetとRoute Tableの関連付け
- Public SubnetをPublicとして機能させるには、IGWへのルートと関連付けが必要

## variables.tf

この段階で使った主な変数:

```hcl
variable "aws_profile" {
  description = "AWS CLI profile used by Terraform."
  type        = string
  default     = "learning"
}

variable "aws_region" {
  description = "AWS region used by this lab."
  type        = string
  default     = "ap-northeast-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}
```

Subnet CIDRやAZも変数化した。

変数化する理由:

- 設計値を `main.tf` から分離できる
- 後からCIDRやAZを変更しやすい
- `main.tf` が「何を作るか」に集中できる

## locals.tf

共通タグを `locals.tf` にまとめた。

```hcl
locals {
  common_tags = {
    Project     = "terraform-iac-lab"
    Environment = "learning"
  }
}
```

各リソースでは `merge` で共通タグとNameタグを結合する。

```hcl
tags = merge(local.common_tags, {
  Name = "sample-vpc"
})
```

これにより、すべてのリソースに `Project` と `Environment` を付けつつ、リソースごとの `Name` を設定できる。

## outputs.tf

`outputs.tf` は、`terraform apply` 後に確認したい値を表示するために使う。

今回出力した値:

```text
vpc_id
public_subnet_ids
private_subnet_ids
internet_gateway_id
public_route_table_id
```

例:

```hcl
output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}
```

`terraform apply` 後に以下のように表示された。

```text
vpc_id = "vpc-09abcd1c84ee3b912"
internet_gateway_id = "igw-00111a8a0a064d17c"
public_route_table_id = "rtb-05b060ccdbad188ec"
```

IDは実行ごとに変わるため、固定値としてコードに書かない。

## 実行手順

作業ディレクトリ:

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

## 実行結果

### terraform init

AWS Providerがインストールされ、初期化に成功した。

```text
Terraform has been successfully initialized!
```

このとき、以下が作成された。

```text
.terraform/
.terraform.lock.hcl
```

`.terraform.lock.hcl` はProviderの選択結果を固定するため、Git管理する。

`.terraform/` はローカルの作業ディレクトリなのでGit管理しない。

### terraform validate

最終的に以下を確認した。

```text
Success! The configuration is valid.
```

途中で変数名のtypoにより、未定義変数エラーが発生した。

例:

```text
An input variable with the name "vpc_cidr" has not been declared.
Did you mean "vpc_cider"?
```

```text
An input variable with the name "availability_zone_1a" has not been declared.
Did you mean "availablity_zone_1a"?
```

原因:

- `vpc_cidr` を `vpc_cider` と書いていた
- `availability` を `availablity` と書いていた

対応:

- `variables.tf` の変数名を `main.tf` の参照名と一致させた
- Terraformのエラーメッセージに `Did you mean ...?` が出るため、typo修正に役立つことを確認した

### terraform plan

以下を確認した。

```text
Plan: 10 to add, 0 to change, 0 to destroy.
```

作成予定リソース:

```text
aws_vpc.main
aws_subnet.public_01
aws_subnet.public_02
aws_subnet.private_01
aws_subnet.private_02
aws_internet_gateway.main
aws_route_table.public
aws_route.public_default
aws_route_table_association.public_01
aws_route_table_association.public_02
```

`plan` で確認するポイント:

- 作成数が想定通りか
- 削除予定が混ざっていないか
- CIDR、AZ、タグが設計通りか
- `map_public_ip_on_launch` がPublic Subnetだけtrueか
- Public Routeが `0.0.0.0/0 -> Internet Gateway` になっているか

### terraform apply

以下を確認した。

```text
Apply complete! Resources: 10 added, 0 changed, 0 destroyed.
```

出力例:

```text
vpc_id = "vpc-09abcd1c84ee3b912"
internet_gateway_id = "igw-00111a8a0a064d17c"
public_route_table_id = "rtb-05b060ccdbad188ec"
public_subnet_ids = [
  "subnet-040f562c042558bca",
  "subnet-02be958fae31b91e6",
]
private_subnet_ids = [
  "subnet-01cb313bbcc189ed4",
  "subnet-0c9ef1ccd17a6a6f6",
]
```

IDは実行時に払い出されるため、次回実行時には変わる。

### terraform destroy

以下を確認した。

```text
Plan: 0 to add, 0 to change, 10 to destroy.
Destroy complete! Resources: 10 destroyed.
```

Terraformで作ったリソースをTerraformで削除できることを確認した。

重要:

Terraformで作成したリソースは、基本的にTerraformで削除する。

AWS CLIやマネジメントコンソールから削除すると、Terraform stateと実AWSの状態がずれる。

## AWS CLIで確認する場合

apply後にAWS CLIで確認する場合:

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-vpc \
  --output table
```

Subnet確認:

```bash
aws ec2 describe-subnets \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Project,Values=terraform-iac-lab \
  --output table
```

Route Table確認:

```bash
aws ec2 describe-route-tables \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-rt-public \
  --output table
```

destroy後に残存確認する場合:

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-vpc \
  --query 'Vpcs[*].VpcId' \
  --output table
```

何も表示されなければ、Terraformで作成したVPCは削除済み。

## 今回学んだこと

- Terraformはリソース参照から依存関係を判断する
- AWS CLIのようにIDを手動で変数に入れて渡す必要がない
- `terraform plan` で作成、変更、削除内容を事前に確認できる
- `terraform apply` 後に `outputs.tf` の値が表示される
- `terraform destroy` でstate管理下のリソースを削除できる
- `terraform validate` は変数名のtypo検出に役立つ
- Terraformで作ったリソースはTerraformで消すのが基本

## 次にやること

次はNAT GatewayとPrivate Route Tableを追加する。

追加予定:

```text
Elastic IP x2
NAT Gateway x2
Private Route Table x2
Private Route x2
Private Route Table Association x2
```

注意:

NAT Gatewayは課金が発生する。

作成後は動作確認を行い、学習が終わったら必ず `terraform destroy` する。
