# 02 NAT Gateway / Private Route Table

このメモでは、TerraformでNAT GatewayとPrivate Route Tableを作成した内容を整理する。

前回の [01 VPC / Subnet / Internet Gateway / Public Route Table](./01_vpc.md) では、以下のネットワーク基盤まで作成した。

```text
VPC
Public Subnet x2
Private Subnet x2
Internet Gateway
Public Route Table
Public Route
Public Route Table Association x2
```

今回は、Private Subnet上のEC2がインターネット方向へ通信できるようにする。

AWS CLI編では、主に以下の範囲に対応する。

```text
04_nat_gateway_setup.sh
05_route_table_setup.sh のPrivate Route Table部分
```

## この段階のゴール

Terraformで以下を追加する。

```text
Elastic IP x2
NAT Gateway x2
Private Route Table x2
Private Route x2
Private Route Table Association x2
```

今回の `terraform plan` では、以下の結果を確認した。

```text
Plan: 20 to add, 0 to change, 0 to destroy.
```

前回のVPC / Subnet / Internet Gateway / Public Route Table構成が10リソースだったため、今回のNAT Gateway関連で10リソース増えた。

内訳は以下。

```text
前回分:
  VPC x1
  Public Subnet x2
  Private Subnet x2
  Internet Gateway x1
  Public Route Table x1
  Public Route x1
  Public Route Table Association x2

今回追加分:
  Elastic IP x2
  NAT Gateway x2
  Private Route Table x2
  Private Route x2
  Private Route Table Association x2
```

## NAT Gatewayの役割

NAT Gatewayは、Private Subnet上のEC2がインターネットへ出ていくための出口である。

ただし、NAT Gateway自体はPrivate SubnetではなくPublic Subnetに配置する。

構成の考え方は以下。

```text
Private Subnet上のEC2
  -> Private Route Table
  -> NAT Gateway
  -> Internet Gateway
  -> Internet
```

重要な点:

- NAT GatewayはPublic Subnetに配置する
- NAT GatewayにはElastic IPを割り当てる
- Private SubnetのRoute Tableで `0.0.0.0/0` をNAT Gatewayへ向ける
- Web EC2はPrivate Subnetに配置したまま、外向き通信だけ可能にする
- Internet側からPrivate SubnetのEC2へ直接入れるようになるわけではない

## 今回の構成

AWS CLI編の構成に合わせて、2つのAvailability ZoneにNAT Gatewayを1台ずつ作成する。

```text
ap-northeast-1a
  Public Subnet 01
    NAT Gateway 01
  Private Subnet 01
    WebServer 01

ap-northeast-1c
  Public Subnet 02
    NAT Gateway 02
  Private Subnet 02
    WebServer 02
```

ルーティングは以下。

```text
Private Subnet 01
  -> Private Route Table 01
  -> 0.0.0.0/0
  -> NAT Gateway 01

Private Subnet 02
  -> Private Route Table 02
  -> 0.0.0.0/0
  -> NAT Gateway 02
```

## 作成したTerraformリソース

今回 `main.tf` に追加したリソースは以下。

```text
aws_eip.nat_01
aws_eip.nat_02
aws_nat_gateway.nat_01
aws_nat_gateway.nat_02
aws_route_table.private_01
aws_route_table.private_02
aws_route.private_01_default
aws_route.private_02_default
aws_route_table_association.private_01
aws_route_table_association.private_02
```

## Elastic IP

NAT GatewayにはElastic IPを割り当てる。

Terraformでは `aws_eip` resourceを使う。

```hcl
resource "aws_eip" "nat_01" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "sample-eip-ngw-01"
  })
}
```

2AZ構成のため、NAT Gateway 01用とNAT Gateway 02用に2つ作成する。

```hcl
resource "aws_eip" "nat_02" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "sample-eip-ngw-02"
  })
}
```

ポイント:

- `domain = "vpc"` はVPC用のElastic IPであることを示す
- NAT Gatewayを削除するときは、Elastic IPも削除しないと課金や残存の原因になる
- Terraform管理にすると、`terraform destroy` でNAT GatewayとElastic IPをまとめて削除できる

## NAT Gateway

Terraformでは `aws_nat_gateway` resourceを使う。

```hcl
resource "aws_nat_gateway" "nat_01" {
  allocation_id = aws_eip.nat_01.id
  subnet_id     = aws_subnet.public_01.id

  tags = merge(local.common_tags, {
    Name = "sample-ngw-01"
  })
}
```

重要なのは以下の2つ。

```hcl
allocation_id = aws_eip.nat_01.id
subnet_id     = aws_subnet.public_01.id
```

意味:

| 項目 | 意味 |
| :--- | :--- |
| `allocation_id` | NAT Gatewayに割り当てるElastic IP |
| `subnet_id` | NAT Gatewayを配置するSubnet |

ここで指定するSubnetはPublic Subnetである。

Private Subnetから使うものだが、NAT Gateway自体はPublic Subnetに置く。

2台目も同じ考え方で、Public Subnet 02へ配置する。

```hcl
resource "aws_nat_gateway" "nat_02" {
  allocation_id = aws_eip.nat_02.id
  subnet_id     = aws_subnet.public_02.id

  tags = merge(local.common_tags, {
    Name = "sample-ngw-02"
  })
}
```

## Private Route Table

Private Subnet用のRoute TableをAZごとに作成する。

```hcl
resource "aws_route_table" "private_01" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "sample-rt-private01"
  })
}
```

```hcl
resource "aws_route_table" "private_02" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "sample-rt-private02"
  })
}
```

Public Route Tableでは、デフォルトルートをInternet Gatewayへ向けた。

```text
Public Route Table
  0.0.0.0/0 -> Internet Gateway
```

Private Route Tableでは、デフォルトルートをNAT Gatewayへ向ける。

```text
Private Route Table
  0.0.0.0/0 -> NAT Gateway
```

## Private Route

Private Subnet 01から外へ出る通信をNAT Gateway 01へ向ける。

```hcl
resource "aws_route" "private_01_default" {
  route_table_id         = aws_route_table.private_01.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_01.id
}
```

Private Subnet 02から外へ出る通信をNAT Gateway 02へ向ける。

```hcl
resource "aws_route" "private_02_default" {
  route_table_id         = aws_route_table.private_02.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_02.id
}
```

ポイント:

- `destination_cidr_block = "0.0.0.0/0"` はインターネット方向全体を意味する
- Public Routeでは `gateway_id = aws_internet_gateway.main.id` を使った
- Private Routeでは `nat_gateway_id = aws_nat_gateway.nat_01.id` を使う
- NAT Gatewayを指定する属性名は `gateway_id` ではなく `nat_gateway_id`

## Route Table Association

Route Tableを作っただけでは、Subnetには適用されない。

SubnetへRoute Tableを関連付ける必要がある。

Private Subnet 01をPrivate Route Table 01に関連付ける。

```hcl
resource "aws_route_table_association" "private_01" {
  subnet_id      = aws_subnet.private_01.id
  route_table_id = aws_route_table.private_01.id
}
```

Private Subnet 02をPrivate Route Table 02に関連付ける。

```hcl
resource "aws_route_table_association" "private_02" {
  subnet_id      = aws_subnet.private_02.id
  route_table_id = aws_route_table.private_02.id
}
```

これにより、Private Subnetごとに別々のNAT Gatewayを使う構成になる。

## Terraformの参照関係

今回のTerraformコードでは、リソースIDを直接書かずに、Terraform resourceを参照している。

例:

```hcl
allocation_id = aws_eip.nat_01.id
subnet_id     = aws_subnet.public_01.id
```

これは以下を意味する。

```text
aws_eip.nat_01 を作成してから、そのIDを NAT Gateway 01 に渡す
aws_subnet.public_01 を作成してから、そのIDを NAT Gateway 01 に渡す
```

この参照関係により、Terraformは作成順序を判断できる。

AWS CLIでは以下のようにID取得と変数渡しを自分で書いていた。

```bash
EIP_ALLOC_ID=$(aws ec2 allocate-address ...)

aws ec2 create-nat-gateway \
  --subnet-id "$PUBLIC_SUBNET_01_ID" \
  --allocation-id "$EIP_ALLOC_ID"
```

Terraformでは、以下のように書くだけで依存関係が表現できる。

```hcl
resource "aws_nat_gateway" "nat_01" {
  allocation_id = aws_eip.nat_01.id
  subnet_id     = aws_subnet.public_01.id
}
```

この点が、AWS CLIのShell ScriptとTerraformの大きな違いである。

## よくあるミス

今回の作業中に出やすかったミスを整理する。

### resource参照を文字列にしてしまう

誤り:

```hcl
subnet_id = "aws_subnet.public_01.id"
```

正しい:

```hcl
subnet_id = aws_subnet.public_01.id
```

ダブルクォートで囲うと、Terraformはただの文字列として扱う。

resourceのIDを参照するときは、クォートで囲まない。

### resource名のtypo

誤り:

```hcl
aws_subnet.public02.id
```

正しい:

```hcl
aws_subnet.public_02.id
```

Terraform resource名は、自分で定義した名前と完全一致させる必要がある。

### Elastic IPの参照名のtypo

誤り:

```hcl
allocation_id = aws_eip_nat_01.id
```

正しい:

```hcl
allocation_id = aws_eip.nat_01.id
```

Terraformのresource参照は以下の形になる。

```text
リソースタイプ.ローカル名.属性
```

今回なら以下。

```text
aws_eip.nat_01.id
```

### NAT Gateway向けRouteの属性名

Public RouteではInternet Gatewayを指定するため、`gateway_id` を使う。

```hcl
gateway_id = aws_internet_gateway.main.id
```

Private RouteでNAT Gatewayを指定するときは、`nat_gateway_id` を使う。

```hcl
nat_gateway_id = aws_nat_gateway.nat_01.id
```

ここを混同しない。

## terraform planの確認観点

`terraform plan` では以下を確認した。

```text
Plan: 20 to add, 0 to change, 0 to destroy.
```

この時点では前回作成したリソースを `terraform destroy` 済みだったため、VPCからNAT Gatewayまで全て新規作成予定になっている。

確認すべきポイント:

- `aws_eip.nat_01` / `aws_eip.nat_02` が作成される
- `aws_nat_gateway.nat_01` / `aws_nat_gateway.nat_02` が作成される
- NAT Gatewayの `connectivity_type` が `public` になっている
- `aws_route.private_01_default` / `aws_route.private_02_default` が作成される
- Private Routeの宛先が `0.0.0.0/0` になっている
- Private Routeに `nat_gateway_id` が設定される
- Private SubnetがPrivate Route Tableに関連付けられる

## 確認コマンド

`terraform apply` 後に確認する場合のコマンド。

NAT Gateway確認:

```bash
aws ec2 describe-nat-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filter "Name=tag:Name,Values=sample-ngw-01,sample-ngw-02" \
  --output table
```

Route Table確認:

```bash
aws ec2 describe-route-tables \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=sample-rt-private01,sample-rt-private02" \
  --output table
```

Terraform output確認:

```bash
terraform output
```

## コスト注意

NAT Gatewayは学習環境では特に注意が必要な課金リソースである。

課金される主な要素:

- NAT Gatewayの稼働時間
- NAT Gatewayを通過するデータ処理量
- Elastic IPの利用状況

そのため、学習目的で `terraform apply` した後は、確認が終わったら `terraform destroy` する。

```bash
terraform destroy
```

AWS CLI版でもNAT Gatewayは削除対象として特に注意していた。

Terraform化しても、NAT Gatewayが高めの課金リソースであることは変わらない。

## この段階で理解したこと

- NAT GatewayはPrivate Subnetの出口だが、配置先はPublic Subnetである
- NAT GatewayにはElastic IPが必要である
- Public SubnetのデフォルトルートはInternet Gatewayへ向ける
- Private SubnetのデフォルトルートはNAT Gatewayへ向ける
- Route Tableは作るだけではSubnetに効かず、Associationが必要である
- Terraformではresource参照により、AWSリソースIDの受け渡しと依存関係を表現できる
- Shell ScriptではID取得、存在確認、順序制御を自分で書く必要があった
- Terraformでは `plan` で作成予定の全体像を事前に確認できる

## 次に進む範囲

次はSecurity GroupをTerraform化する。

AWS CLI編では以下に対応する。

```text
06_security_group_setup.sh
```

Security Groupでは、以下の通信を整理する。

```text
User -> Bastion: SSH 22
User -> ALB: HTTP 80 / HTTPS 443
ALB -> Web EC2: HTTP 3000
Bastion -> Web EC2: SSH 22
Web EC2 -> RDS: MySQL 3306
Web EC2 -> ElastiCache: Redis 6379
```

Terraformでは、`aws_security_group` と `aws_security_group_rule` または `ingress` / `egress` blockを使って表現する。
