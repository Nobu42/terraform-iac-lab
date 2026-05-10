# 03 Security Group

このメモでは、TerraformでSecurity Group本体とInbound / Outbound Ruleを作成した内容を整理する。

前回までに、VPC、Subnet、Internet Gateway、NAT Gateway、Route TableまでTerraform化した。

今回は、後続のEC2、ALB、RDS、ElastiCacheで利用する通信制御をTerraformで表現する。

AWS CLI編では、主に以下の範囲に対応する。

```text
06_security_group_setup.sh
```

## この段階のゴール

Terraformで以下を作成する。

```text
Security Group本体 x5
Inbound Rule x7
Outbound Rule x5
```

今回の `terraform plan` では、Security Groupまで含めて以下の結果を確認した。

```text
Plan: 37 to add, 0 to change, 0 to destroy.
```

内訳は以下。

```text
ネットワーク基盤              20
Security Group本体            5
Security Group Inbound Rule    7
Security Group Outbound Rule   5
合計                           37
```

## 作成するSecurity Group

AWS CLI編の構成に合わせて、以下の5つを作成する。

```text
sample-sg-bastion
sample-sg-elb
sample-sg-web
sample-sg-db
sample-sg-elasticache
```

役割:

| Security Group | 用途 |
| :--- | :--- |
| `sample-sg-bastion` | 踏み台サーバー用 |
| `sample-sg-elb` | Application Load Balancer用 |
| `sample-sg-web` | Web EC2用 |
| `sample-sg-db` | RDS MySQL用 |
| `sample-sg-elasticache` | ElastiCache Redis用 |

## 通信設計

この構成で許可する主な通信は以下。

```text
管理者IP -> Bastion: SSH 22
Internet -> ALB: HTTP 80
Internet -> ALB: HTTPS 443
ALB -> Web EC2: HTTP 3000
Bastion -> Web EC2: SSH 22
Web EC2 -> RDS: MySQL 3306
Web EC2 -> ElastiCache: Redis 6379
```

Publicに開けるのは以下だけにする。

```text
Bastion: SSH 22 from admin_ip_cidr
ALB: HTTP 80 / HTTPS 443 from 0.0.0.0/0
```

Web EC2、RDS、ElastiCacheはインターネットから直接アクセスさせない。

## Security Group本体

Terraformでは `aws_security_group` resourceでSecurity Group本体を作成する。

例:

```hcl
resource "aws_security_group" "bastion" {
  name        = "sample-sg-bastion"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "sample-sg-bastion"
  })
}
```

今回作成したSecurity Group本体:

```text
aws_security_group.bastion
aws_security_group.elb
aws_security_group.web
aws_security_group.db
aws_security_group.elasticache
```

ポイント:

- `name` はAWS上に表示されるSecurity Group名
- `description` はSecurity Groupの説明
- `vpc_id` で対象VPCを指定する
- `tags.Name` もAWSコンソール上の識別に使う

## Ruleを分けて書く方針

Security Groupのルールは2通りで書ける。

```text
1. aws_security_group の中に ingress / egress blockを書く
2. aws_security_group_rule として別resourceに分ける
```

今回は `aws_security_group_rule` に分けて書いた。

理由:

- Security Group同士の参照が多い
- ルール単位で何を許可しているか読みやすい
- 後からルールを追加・削除しやすい
- 学習メモとして通信設計を追いやすい

## Inbound Rule

Inboundは、外部または別Security Groupから入ってくる通信を許可する。

### Bastion SSH

```hcl
resource "aws_security_group_rule" "bastion_ingress_ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.bastion.id

  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [var.admin_ip_cidr]

  description = "Allow SSH from admin IP"
}
```

`admin_ip_cidr` は `variables.tf` で定義する。

```hcl
variable "admin_ip_cidr" {
  description = "CIDR block allowed to SSH to the bastion host. Example: x.x.x.x/32"
  type        = string
}
```

GitHubへ自宅のグローバルIPを直接書かないため、変数として入力する。

`terraform plan` 実行時に以下のように聞かれたら、CIDR形式で入力する。

```text
var.admin_ip_cidr
  Enter a value: x.x.x.x/32
```

`/32` はIPv4で「その1つのIPアドレスだけ」を意味する。

### ALB HTTP / HTTPS

ALBはインターネットからHTTP / HTTPSを受ける。

```hcl
resource "aws_security_group_rule" "elb_ingress_http" {
  type              = "ingress"
  security_group_id = aws_security_group.elb.id

  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  description = "Allow HTTP from internet"
}
```

```hcl
resource "aws_security_group_rule" "elb_ingress_https" {
  type              = "ingress"
  security_group_id = aws_security_group.elb.id

  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  description = "Allow HTTPS from internet"
}
```

`0.0.0.0/0` はIPv4の全範囲を意味する。

ALBは公開入口なので、HTTP / HTTPSは全体に開ける。

### ALBからWeb EC2

ALBからWeb EC2の3000番へ転送する。

```hcl
resource "aws_security_group_rule" "web_ingress_http_from_elb" {
  type              = "ingress"
  security_group_id = aws_security_group.web.id

  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.elb.id

  description = "Allow HTTP 3000 from ALB"
}
```

ここでは `cidr_blocks` ではなく、`source_security_group_id` を使う。

意味:

```text
ALB Security Groupに属するリソースからだけ、Web Security Groupの3000番へ入れる
```

IPアドレスではなくSecurity Groupを許可元にすることで、ALBのIP変化を意識しなくてよい。

### BastionからWeb EC2

Private Subnet上のWeb EC2へSSHするため、BastionからのSSHを許可する。

```hcl
resource "aws_security_group_rule" "web_ingress_ssh_from_bastion" {
  type              = "ingress"
  security_group_id = aws_security_group.web.id

  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id

  description = "Allow SSH from bastion"
}
```

Web EC2にはインターネットから直接SSHしない。

```text
管理者 -> Bastion -> Web EC2
```

という経路にする。

### Web EC2からRDS

RailsアプリケーションがRDS MySQLへ接続するため、Web Security GroupからDB Security Groupの3306番を許可する。

```hcl
resource "aws_security_group_rule" "db_ingress_mysql_from_web" {
  type              = "ingress"
  security_group_id = aws_security_group.db.id

  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id

  description = "Allow MySQL from web servers"
}
```

### Web EC2からElastiCache

RailsアプリケーションがRedisへ接続するため、Web Security GroupからElastiCache Security Groupの6379番を許可する。

```hcl
resource "aws_security_group_rule" "elasticache_ingress_redis_from_web" {
  type              = "ingress"
  security_group_id = aws_security_group.elasticache.id

  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id

  description = "Allow Redis from web servers"
}
```

## Outbound Rule

Outboundは、Security Groupから外へ出る通信を許可する。

今回は学習環境として、詰まりにくさを優先し、以下の方針にした。

```text
Bastion: all outbound
ALB: Web EC2の3000番のみ
Web EC2: all outbound
RDS: all outbound
ElastiCache: all outbound
```

### Bastion outbound

```hcl
resource "aws_security_group_rule" "bastion_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.bastion.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  description = "Allow all outbound from bastion"
}
```

`protocol = "-1"` は全プロトコルを意味する。

`from_port = 0` / `to_port = 0` は、全プロトコル指定時の慣用的な書き方である。

### ALB outbound

ALBからWeb EC2の3000番へ出る通信だけを許可する。

```hcl
resource "aws_security_group_rule" "elb_egress_http_to_web" {
  type              = "egress"
  security_group_id = aws_security_group.elb.id

  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id

  description = "Allow HTTP 3000 to web servers"
}
```

`egress` でも相手側Security Group指定には `source_security_group_id` を使う。

属性名は少し紛らわしいが、ここでは「通信相手のSecurity Group」と考える。

### Web EC2 outbound

Web EC2は以下のような外向き通信が必要になる。

```text
dnf / yum
Ruby gem
S3
SES SMTP
CloudWatch Agent
外部API
```

そのため、学習環境では全Outboundを許可する。

```hcl
resource "aws_security_group_rule" "web_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.web.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  description = "Allow all outbound from web servers"
}
```

### DB / ElastiCache outbound

RDSとElastiCacheは基本的には受け側だが、AWSのデフォルトSecurity Group挙動に近づけるため、学習環境では全Outboundを明示した。

```hcl
resource "aws_security_group_rule" "db_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.db.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  description = "Allow all outbound from RDS security group"
}
```

```hcl
resource "aws_security_group_rule" "elasticache_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.elasticache.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  description = "Allow all outbound from ElastiCache security group"
}
```

本番構成では、より厳密なOutbound制御を検討する。

## よくあるミス

### CIDRを文字列にし忘れる

誤り:

```hcl
cidr_blocks = [0.0.0.0/0]
```

正しい:

```hcl
cidr_blocks = ["0.0.0.0/0"]
```

CIDRは文字列として書く。

### `/32` を付け忘れる

誤り:

```text
x.x.x.x
```

正しい:

```text
x.x.x.x/32
```

`cidr_blocks` はCIDR形式が必要である。

IPアドレス1個だけを許可する場合は `/32` を付ける。

### `aws_security_group` と `aws_security_group_rule` を間違える

誤り:

```hcl
resource "aws_security_group" "bastion_egress_all" {
  type = "egress"
}
```

正しい:

```hcl
resource "aws_security_group_rule" "bastion_egress_all" {
  type = "egress"
}
```

`aws_security_group` はSecurity Group本体。

`aws_security_group_rule` はSecurity Groupのルール。

### `description` のtypo

誤り:

```hcl
destination = "Allow all outbound from bastion"
```

正しい:

```hcl
description = "Allow all outbound from bastion"
```

Terraformは未対応の引数があると `Unsupported argument` として検出する。

## terraform planの確認観点

Security Groupまで追加した時点で、以下を確認した。

```text
Plan: 37 to add, 0 to change, 0 to destroy.
```

確認ポイント:

- Security Group本体が5つ作成される
- Inbound Ruleが7つ作成される
- Outbound Ruleが5つ作成される
- Bastion SSHの許可元が `admin_ip_cidr` になっている
- ALB HTTP / HTTPSは `0.0.0.0/0` になっている
- Web EC2への3000番はALB Security Groupからだけ許可される
- Web EC2への22番はBastion Security Groupからだけ許可される
- RDS 3306はWeb Security Groupからだけ許可される
- Redis 6379はWeb Security Groupからだけ許可される

## この段階で理解したこと

- Security GroupはAWS上の仮想ファイアウォールである
- Publicに開ける通信と、Security Group間だけで許可する通信を分けて考える
- `cidr_blocks` はIPアドレス範囲を許可元・許可先にする
- `source_security_group_id` はSecurity Groupを許可元・許可先にする
- `aws_security_group` と `aws_security_group_rule` は役割が違う
- Terraformでは通信ルールを1つずつresourceとして明示できる
- `terraform validate` はtypoやresource種別間違いを検出できる

## 次に進む範囲

次はEC2の前提リソースとEC2本体をTerraform化する。

まずは以下を扱う。

```text
aws_key_pair
data "aws_ami"
aws_iam_role
aws_iam_instance_profile
aws_instance
```

AWS CLI編では以下に対応する。

```text
07_bastion_server_setup.sh
08_Web_server_setup.sh
```
