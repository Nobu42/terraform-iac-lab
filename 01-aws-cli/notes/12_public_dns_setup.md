# 12 Public DNS Setup

## 目的

AWS CLIでRoute 53のPublic Hosted ZoneにDNSレコードを作成する。

この手順では、取得済みドメイン `nobu-iac-lab.com` に対して、踏み台サーバーとロードバランサー用のPublic DNSを設定する。

- `bastion.nobu-iac-lab.com` を踏み台サーバーのPublic IPへ向ける
- `www.nobu-iac-lab.com` をApplication Load BalancerへAliasレコードで向ける

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース: Route 53, EC2, ALB
- 前提:
  - `nobu-iac-lab.com` をRoute 53で管理していること
  - Public Hosted Zoneが作成済みであること
  - `sample-ec2-bastion` が起動済みであること
  - `sample-elb` が作成済みであること
  - ALBまでの構築が完了していること

## 設計値

| 項目 | 値 |
| :--- | :--- |
| ドメイン名 | nobu-iac-lab.com |
| Public Hosted Zone | nobu-iac-lab.com |
| Bastionレコード | bastion.nobu-iac-lab.com |
| ALBレコード | www.nobu-iac-lab.com |
| Bastionレコードタイプ | A |
| ALBレコードタイプ | A Alias |
| Bastion TTL | 300 |
| ルーティングポリシー | シンプルルーティング |

## DNS設計

| レコード名 | タイプ | ルーティング先 | 用途 |
| :--- | :--- | :--- | :--- |
| bastion.nobu-iac-lab.com | A | Bastion Public IP | 踏み台サーバーへのSSH接続用 |
| www.nobu-iac-lab.com | A Alias | Application Load Balancer | Webアプリケーション公開用 |

## スクリプト

- [12_public_dns_setup.sh](../scripts/12_public_dns_setup.sh)

## 実行コマンド

```bash
./12_public_dns_setup.sh
```

## 実AWSでの実行結果

Public Hosted Zoneに以下のDNSレコードを作成した。

| Name | Type | Value / Alias |
| :--- | :--- | :--- |
| bastion.nobu-iac-lab.com | A | Bastion Public IP |
| www.nobu-iac-lab.com | A Alias | sample-elb |

実行時の主な出力:

```text
Hosted Zone ID: Z02886402CZFSQE5OSSQ
Bastion Public IP: 43.206.215.171
ALB DNS Name: sample-elb-1806338216.ap-northeast-1.elb.amazonaws.com
ALB Canonical Hosted Zone ID: Z14GRHDCWA56QT
DNS change is INSYNC.
```

## 確認コマンド

Route 53上のレコードを確認する。

```bash
aws route53 list-resource-record-sets \
  --profile learning \
  --hosted-zone-id Z02886402CZFSQE5OSSQ \
  --query 'ResourceRecordSets[?Name==`bastion.nobu-iac-lab.com.` || Name==`www.nobu-iac-lab.com.`]' \
  --output table
```

DNS名前解決を確認する。

```bash
dig bastion.nobu-iac-lab.com
dig www.nobu-iac-lab.com
```

または簡易的に確認する。

```bash
nslookup bastion.nobu-iac-lab.com
nslookup www.nobu-iac-lab.com
```

ALB経由でWebアプリケーションにアクセスする。

```bash
curl http://www.nobu-iac-lab.com
```

ブラウザから確認する場合:

```text
http://www.nobu-iac-lab.com
```

## SSH接続確認

`bastion.nobu-iac-lab.com` を使って踏み台サーバーへSSH接続できる。

```bash
ssh -i nobu.pem ec2-user@bastion.nobu-iac-lab.com
```

`~/.ssh/config` を使う場合は、HostNameをPublic IPではなくDNS名にできる。

```sshconfig
Host bastion
  HostName bastion.nobu-iac-lab.com
  User ec2-user
  IdentityFile /path/to/nobu.pem
  IdentitiesOnly yes
```

## 学んだこと

- Route 53のPublic Hosted ZoneにAレコードを作成できる
- EC2のPublic IPに対して通常のAレコードを設定できる
- ALBには通常のIPアドレスではなく、Aliasレコードで向ける
- ALB AliasにはALBのDNS名とCanonical Hosted Zone IDが必要になる
- `UPSERT` を使うことで、既存レコードがある場合は更新、ない場合は作成できる
- `INSYNC` になればRoute 53上の変更は反映済みになる
- EC2を作り直すとBastionのPublic IPは変わるため、DNSレコードも更新が必要になる
- ALBを作り直しても、スクリプトを再実行すれば新しいALBへDNSを向け直せる

## 注意事項

`bastion.nobu-iac-lab.com` はインターネット上で名前解決できるPublic DNSである。Security Groupでは、自分のグローバルIPからのSSHのみを許可する。

BastionにElastic IPを割り当てていないため、EC2を作り直すとPublic IPが変わる。その場合はこのスクリプトを再実行してDNSレコードを更新する。

`www.nobu-iac-lab.com` はALBへ向くが、HTTPSではなくHTTPでの確認となる。HTTPS化はACM証明書を作成し、ALBの443 Listenerを設定する手順で行う。

## 削除時の注意

Public Hosted Zone自体はドメイン管理に必要なため、通常は削除しない。

DNSレコードだけ削除する場合は、対象レコードを `DELETE` する。学習用の削除スクリプトでは、Hosted Zoneを残し、`bastion` や `www` など作成したレコードのみ削除する運用が安全である。

ドメイン登録料は年額課金であり、Hosted ZoneやDNSレコードを削除しても返金されない。

