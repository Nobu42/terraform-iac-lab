# 05 EC2 / ALB

このメモでは、TerraformでIAM Role、EC2、Application Load Balancerを作成し、ALBまで到達確認した内容を整理する。

前回までに、以下をTerraform化した。

```text
VPC
Public Subnet / Private Subnet
Internet Gateway
NAT Gateway
Route Table
Security Group
EC2 Key Pair
AMI取得
```

今回は、EC2本体とALBを追加した。

AWS CLI編では、主に以下の範囲に対応する。

```text
07_bastion_server_setup.sh
08_Web_server_setup.sh
09_LoadBalancer_setup.sh
```

## この段階のゴール

Terraformで以下を作成する。

```text
Web EC2用IAM Role
IAM Instance Profile
IAM Policy Attachment
Bastion EC2
Web EC2 x2
ALB Target Group
Application Load Balancer
HTTP Listener
Target Group Attachment x2
```

最終的に、ALBのDNS名へHTTPアクセスし、ALBまで到達できることを確認する。

## 作成結果

この段階で `terraform apply` を実行し、以下を確認した。

```text
Apply complete! Resources: 51 added, 0 changed, 0 destroyed.
```

作成後、`terraform output` により以下の情報を確認した。

```text
alb_dns_name
bastion_public_ip
bastion_private_ip
web_01_private_ip
web_02_private_ip
web_instance_ids
target_group_arn
target_group_name
```

実際のPublic IPやInstance IDは変化するため、このメモには固定値としては残さない。

## IAM Role / Instance Profile

Web EC2がS3、CloudWatch Logs、SSMを利用できるように、Web EC2用のIAM Roleを作成した。

Terraform resource:

```text
aws_iam_role.web
aws_iam_instance_profile.web
aws_iam_role_policy_attachment.web_s3
aws_iam_role_policy_attachment.web_cloudwatch_agent
aws_iam_role_policy_attachment.web_ssm
```

### IAM Role

```hcl
resource "aws_iam_role" "web" {
  name = "sample-role-web"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "sample-role-web"
  })
}
```

`assume_role_policy` は「誰がこのRoleを使えるか」を定義する。

今回はEC2に使わせるため、以下を指定する。

```hcl
Service = "ec2.amazonaws.com"
```

### Instance Profile

EC2にIAM Roleを付けるには、Roleを直接指定するのではなくInstance Profileを使う。

```hcl
resource "aws_iam_instance_profile" "web" {
  name = "sample-instance-profile-web"
  role = aws_iam_role.web.name

  tags = merge(local.common_tags, {
    Name = "sample-instance-profile-web"
  })
}
```

関係は以下。

```text
IAM Role
  -> IAM Instance Profile
  -> EC2
```

`aws_instance` では以下のように指定する。

```hcl
iam_instance_profile = aws_iam_instance_profile.web.name
```

### Policy Attachment

学習環境では、まずAWS管理ポリシーをattachした。

```hcl
resource "aws_iam_role_policy_attachment" "web_s3" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
```

```hcl
resource "aws_iam_role_policy_attachment" "web_cloudwatch_agent" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
```

```hcl
resource "aws_iam_role_policy_attachment" "web_ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

付与した権限:

| Policy | 用途 |
| :--- | :--- |
| `AmazonS3FullAccess` | Rails Active StorageでS3へ画像保存 |
| `CloudWatchAgentServerPolicy` | CloudWatch Agentによるログ送信 |
| `AmazonSSMManagedInstanceCore` | Session Managerなどの運用確認 |

本番構成では、`AmazonS3FullAccess` ではなく対象Bucketに絞った最小権限Policyを検討する。

## Bastion EC2

Bastion EC2はPublic Subnetに配置し、管理者がSSHで接続する踏み台サーバーとして使う。

```hcl
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_01.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = true

  tags = merge(local.common_tags, {
    Name = "sample-ec2-bastion"
  })
}
```

ポイント:

- BastionはPublic Subnetに配置する
- Public IPを付与する
- Security Groupは `sample-sg-bastion`
- SSH用Key Pairは `aws_key_pair.main`
- AMIはAmazon Linux 2023を使う

## Web EC2

Web EC2はPrivate Subnetに2台配置する。

```hcl
resource "aws_instance" "web_01" {
  ami                         = local.web_ami_id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private_01.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.main.key_name
  iam_instance_profile        = aws_iam_instance_profile.web.name
  associate_public_ip_address = false

  tags = merge(local.common_tags, {
    Name = "sample-ec2-web01"
  })
}
```

```hcl
resource "aws_instance" "web_02" {
  ami                         = local.web_ami_id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private_02.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.main.key_name
  iam_instance_profile        = aws_iam_instance_profile.web.name
  associate_public_ip_address = false

  tags = merge(local.common_tags, {
    Name = "sample-ec2-web02"
  })
}
```

ポイント:

- Web EC2はPrivate Subnetに配置する
- Public IPは付与しない
- Security Groupは `sample-sg-web`
- IAM Instance Profileを付ける
- AMIは `local.web_ami_id` を使う

`local.web_ami_id` により、標準のAmazon Linux 2023 AMIとカスタムAMIを切り替えられる。

```hcl
web_ami_id = var.use_custom_web_ami ? var.custom_web_ami_id : data.aws_ami.amazon_linux_2023.id
```

## ALB Target Group

Web EC2の3000番へ転送するため、Target Groupを作成した。

```hcl
resource "aws_lb_target_group" "web" {
  name        = "sample-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = merge(local.common_tags, {
    Name = "sample-tg"
  })
}
```

ポイント:

- `target_type = "instance"` でEC2 Instance IDをTargetにする
- ALBからWeb EC2の3000番へ転送する
- Health Checkは `/` にHTTPアクセスする
- `matcher = "200-399"` で正常レスポンス範囲を指定する

## Application Load Balancer

ALBはPublic Subnet 2つに配置する。

```hcl
resource "aws_lb" "web" {
  name               = "sample-elb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.elb.id]
  subnets = [
    aws_subnet.public_01.id,
    aws_subnet.public_02.id
  ]

  tags = merge(local.common_tags, {
    Name = "sample-elb"
  })
}
```

ポイント:

- `load_balancer_type = "application"` でALBを作成する
- `internal = false` でインターネット向けALBにする
- ALB用Security Groupを付ける
- Public Subnet 01 / 02 に配置する

## HTTP Listener

まずはHTTP 80でTarget Groupへforwardする。

```hcl
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
```

HTTPS化、ACM証明書、HTTPからHTTPSへのリダイレクトは後続で追加する。

## Target Group Attachment

Web EC2 2台をTarget Groupへ登録する。

```hcl
resource "aws_lb_target_group_attachment" "web_01" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_01.id
  port             = 3000
}
```

```hcl
resource "aws_lb_target_group_attachment" "web_02" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_02.id
  port             = 3000
}
```

関係:

```text
ALB
  -> Listener :80
  -> Target Group
  -> Web EC2 01:3000
  -> Web EC2 02:3000
```

## outputs.tf

EC2とALBの確認に必要な値を `outputs.tf` に追加した。

EC2:

```text
bastion_instance_id
bastion_public_ip
bastion_private_ip
web_01_instance_id
web_01_private_ip
web_02_instance_id
web_02_private_ip
web_instance_ids
web_private_ips
```

ALB:

```text
alb_dns_name
alb_arn
alb_zone_id
target_group_arn
target_group_name
```

ALB DNS名は、apply後に以下で確認できる。

```bash
terraform output -raw alb_dns_name
```

HTTP疎通確認:

```bash
curl -I http://$(terraform output -raw alb_dns_name)
```

## terraform planの推移

今回の作業では、段階的に `terraform plan` を確認した。

```text
Security Groupまで:
  Plan: 37 to add, 0 to change, 0 to destroy.

Key Pair追加:
  Plan: 38 to add, 0 to change, 0 to destroy.

IAM Role / Instance Profile追加:
  Plan: 43 to add, 0 to change, 0 to destroy.

Bastion EC2追加:
  Plan: 44 to add, 0 to change, 0 to destroy.

Web EC2 x2追加:
  Plan: 46 to add, 0 to change, 0 to destroy.

ALB関連追加:
  Plan: 51 to add, 0 to change, 0 to destroy.
```

outputs追加ではリソース数は変わらず、`Changes to Outputs` だけが増えた。

## apply結果

`terraform apply` により、以下を確認した。

```text
Apply complete! Resources: 51 added, 0 changed, 0 destroyed.
```

この時点で、Terraformから以下の主要リソースを作成できた。

```text
VPC
Subnet
Internet Gateway
NAT Gateway
Route Table
Security Group
Key Pair
IAM Role / Instance Profile
Bastion EC2
Web EC2 x2
ALB
Target Group
HTTP Listener
Target Group Attachment
```

## ALB疎通確認

ALB DNS名へHTTP HEADリクエストを送信した。

```bash
curl -I http://$(terraform output -raw alb_dns_name)
```

結果:

```text
HTTP/1.1 502 Bad Gateway
Server: awselb/2.0
```

これは、ALBまでは到達していることを示す。

ただし、Web EC2上でまだWebアプリケーションや簡易HTTPサーバが起動していないため、ALBからWeb EC2:3000への転送先が応答できず、502になっている。

つまり状態は以下。

```text
Client -> ALB:80        OK
ALB -> Target Group     OK
Target Group -> EC2:3000 NG
```

## Target Group Health確認

Target GroupのHealth Check状態を確認した。

```bash
aws elbv2 describe-target-health \
  --profile learning \
  --region ap-northeast-1 \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --output table
```

結果:

```text
State: unhealthy
Reason: Target.FailedHealthChecks
Description: Health checks failed
HealthCheckPort: 3000
```

これは、Target GroupにWeb EC2 2台が登録されているが、3000番でHealth Checkに成功していない状態である。

理由は、Web EC2上でまだ3000番のアプリケーションが起動していないため。

この結果は、ALBやTarget GroupのTerraform定義が失敗しているというより、アプリケーション層が未構築であることを示している。

## 502 Bad Gatewayの判断

今回の502は、以下のように判断した。

```text
HTTPレスポンスヘッダー:
  Server: awselb/2.0

Target Group Health:
  State: unhealthy
  Reason: Target.FailedHealthChecks
```

このため、ALB自体には到達している。

一方で、TargetのWeb EC2がHealth Checkに失敗しているため、ALBが正常な転送先を持てず502を返している。

今後、Web EC2上で以下のいずれかを起動すれば、Health Checkが改善する。

```text
簡易HTTPサーバ
nginx
Puma / Railsアプリケーション
```

## 次に進む範囲

次の選択肢は2つある。

### 1. Terraformのuser_dataで簡易HTTPサーバを起動する

TerraformだけでALB疎通確認を完結させる方法。

例:

```text
Web EC2起動時に簡易HTMLを配置
python3 -m http.server 3000
```

これにより、Target Group Healthが `healthy` になることを確認できる。

### 2. Ansibleと連携する

Terraformで作成したEC2のIPを使ってAnsible inventoryを更新し、nginx / Ruby / Rails / Pumaを構築する方法。

本来のポートフォリオ構成に近い。

ただし、Terraform outputから以下を取り出してinventoryへ反映する必要がある。

```text
bastion_public_ip
web_01_private_ip
web_02_private_ip
```

## コスト注意

この段階では、NAT Gateway、EC2、ALBが作成される。

学習後は、不要な場合は `terraform destroy` する。

```bash
terraform destroy
```

特にNAT GatewayとALBは、起動したまま放置しないように注意する。
