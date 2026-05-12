# 08 Route 53 / ACM

このメモでは、既存のRoute 53 Public Hosted ZoneとACM証明書をTerraformから参照し、ALBのHTTPS化とDNS Alias Recordを作成した内容を整理する。

AWS CLI編では、主に以下に対応する。

```text
12_public_dns_setup.sh
15_acm_certificate_setup.sh
```

## この段階のゴール

既存のドメインとACM証明書を使い、以下のURLをALBへ向ける。

```text
https://www.nobu-iac-lab.com
```

作成・参照するTerraform block:

```text
data "aws_route53_zone" "public"
data "aws_acm_certificate" "app"
aws_route53_record.www
aws_lb_listener.https
aws_lb_listener.http のredirect化
```

Route 53 / ACM追加後の `terraform plan` は以下。

```text
Plan: 62 to add, 0 to change, 0 to destroy.
```

前回のS3までが60リソースだったため、作成リソースは2つ増えた。

```text
60 + 2 = 62
```

`data` は参照だけなので、作成数には含まれない。

## 既存リソースはdata sourceで参照する

ドメイン登録、Public Hosted Zone、ACM証明書本体はすでに作成済みで、日次削除しない。

そのため、最初からTerraformで新規作成せず、まずはdata sourceで参照する。

理由:

- ドメインや証明書は誤削除したくない
- ACM DNS検証レコードやSES関連レコードも既に存在する
- 後で必要になったら `terraform import` を検討できる

## variables.tf

ドメイン名を変数化した。

```hcl
variable "domain_name" {
  description = "Root domain name managed by Route 53."
  type        = string
  default     = "nobu-iac-lab.com"
}
```

```hcl
variable "app_domain_name" {
  description = "Application domain name for ALB."
  type        = string
  default     = "www.nobu-iac-lab.com"
}
```

## Public Hosted Zone参照

既存のPublic Hosted Zoneを参照する。

```hcl
data "aws_route53_zone" "public" {
  name         = var.domain_name
  private_zone = false
}
```

`private_zone = false` により、Public Hosted Zoneを対象にする。

## ACM証明書参照

既存のACM証明書を参照する。

```hcl
data "aws_acm_certificate" "app" {
  domain      = var.app_domain_name
  statuses    = ["ISSUED"]
  most_recent = true
}
```

ポイント:

- ALBで使うACM証明書はALBと同じリージョンに存在する必要がある
- 今回は `ap-northeast-1` の証明書を参照する
- `statuses = ["ISSUED"]` で発行済み証明書だけを対象にする

## Route 53 Alias Record

`www.nobu-iac-lab.com` をALBへ向けるAlias Recordを作成する。

```hcl
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = var.app_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.web.dns_name
    zone_id                = aws_lb.web.zone_id
    evaluate_target_health = false
  }
}
```

ALBへRoute 53 Aliasを作成する場合は、ALBのDNS名とZone IDを使う。

```hcl
name    = aws_lb.web.dns_name
zone_id = aws_lb.web.zone_id
```

## HTTPS Listener

ALBでHTTPS 443を受け、Target Groupへforwardする。

```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.aws_acm_certificate.app.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
```

`certificate_arn` に既存ACM証明書のARNを指定する。

## HTTP ListenerのHTTPSリダイレクト

HTTP 80はTarget Groupへ直接forwardせず、HTTPS 443へリダイレクトする。

```hcl
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
```

これにより、HTTPアクセスはHTTPSへ誘導される。

## outputs.tf

確認用に以下をoutputした。

```hcl
output "public_hosted_zone_id" {
  description = "Route 53 public hosted zone ID."
  value       = data.aws_route53_zone.public.zone_id
}
```

```hcl
output "app_url" {
  description = "HTTPS URL of the application."
  value       = "https://${var.app_domain_name}"
}
```

```hcl
output "acm_certificate_arn" {
  description = "ARN of the ACM certificate used by ALB HTTPS listener."
  value       = data.aws_acm_certificate.app.arn
}
```

ACM ARNやHosted Zone IDは秘密情報ではないが、AWSアカウントIDなどが見える情報ではある。

公開リポジトリで気になる場合は、`acm_certificate_arn` outputは削ってもよい。

## 確認観点

`terraform plan` で見るポイント:

- Hosted ZoneとACM証明書はdata sourceとして参照される
- `aws_route53_record.www` が作成される
- `aws_lb_listener.https` が作成される
- HTTP ListenerはHTTPS redirectになっている
- `app_url` が `https://www.nobu-iac-lab.com` になる

## 注意点

Route 53 Public Hosted Zone本体やACM証明書本体をTerraform管理に入れていない。

これは意図的な判断である。

既存の継続利用リソースは、まずdata sourceで参照し、必要になったらimportを検討する。
