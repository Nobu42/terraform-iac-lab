# 15 ACM Certificate Setup

## 目的

AWS CLIでACM証明書を発行し、Application Load BalancerにHTTPS Listenerを追加する。

この手順では、`www.nobu-iac-lab.com` 用のSSL/TLS証明書をACMで作成し、DNS検証をRoute 53で行う。
証明書が発行された後、ALBにHTTPS 443番ポートのListenerを作成し、Target Group `sample-tg` へ転送する。

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース: ACM, Route 53, ALB
- 前提:
  - `nobu-iac-lab.com` をRoute 53で管理していること
  - Public Hosted Zoneが作成済みであること
  - `www.nobu-iac-lab.com` がALBへ向いていること
  - `sample-elb` が作成済みであること
  - `sample-tg` が作成済みであること
  - ALBのSecurity GroupでHTTPS 443/tcpを許可していること

## 設計値

| 項目 | 値 |
| :--- | :--- |
| 証明書対象ドメイン | www.nobu-iac-lab.com |
| 証明書サービス | AWS Certificate Manager |
| 検証方式 | DNS検証 |
| DNS管理 | Route 53 |
| ALB名 | sample-elb |
| Listener Protocol | HTTPS |
| Listener Port | 443 |
| Default action | forward |
| Target Group | sample-tg |
| Security policy | AWSが用意しているデフォルト設定を利用 |

## スクリプト

- [15_acm_certificate_setup.sh](../scripts/15_acm_certificate_setup.sh)

## 実行コマンド

```bash
./15_acm_certificate_setup.sh
```

## 処理内容

このスクリプトでは以下を行う。

1. Public Hosted Zoneを取得する
2. `www.nobu-iac-lab.com` のACM証明書を確認する
3. 証明書が存在しない場合は新規リクエストする
4. ACMが発行するDNS検証用CNAMEを取得する
5. Route 53にDNS検証用CNAMEを作成する
6. 証明書が `ISSUED` になるまで待つ
7. ALB `sample-elb` を取得する
8. Target Group `sample-tg` を取得する
9. HTTPS 443 Listenerを作成する
10. Default actionとして `sample-tg` へforwardする

## 実AWSでの実行結果

ACM証明書をリクエストし、DNS検証をRoute 53で行った。

実行時の主な出力:

```text
Hosted Zone ID: Z02886402CZFSQE5OSSQ
ACM Certificate requested: arn:aws:acm:ap-northeast-1:445405559057:certificate/331011aa-f281-4599-b3a1-c8545805208b
Validation Record Name: _c497f1fd492da2931acd977e27407b46.www.nobu-iac-lab.com.
Validation Record Value: _d3ac093a285825893feeb535f873d85e.jkddzztszm.acm-validations.aws.
DNS validation record is INSYNC.
ACM Certificate is ISSUED.
```

ALBにHTTPS Listenerを作成した。

```text
Protocol: HTTPS
Port: 443
Default action: forward
Target Group: sample-tg
```

証明書の状態:

| DomainName | Status | Type | Issuer |
| :--- | :--- | :--- | :--- |
| www.nobu-iac-lab.com | ISSUED | AMAZON_ISSUED | Amazon |

## 確認コマンド

ACM証明書の状態を確認する。

```bash
aws acm describe-certificate \
  --profile learning \
  --region ap-northeast-1 \
  --certificate-arn <Certificate ARN> \
  --query 'Certificate.{DomainName:DomainName,Status:Status,Type:Type,Issuer:Issuer,NotAfter:NotAfter}' \
  --output table
```

ALB Listenerを確認する。

```bash
aws elbv2 describe-listeners \
  --profile learning \
  --region ap-northeast-1 \
  --load-balancer-arn <ALB ARN> \
  --query 'Listeners[*].{Port:Port,Protocol:Protocol,ListenerArn:ListenerArn,DefaultActions:DefaultActions[*].Type,Certificate:Certificates[0].CertificateArn}' \
  --output table
```

ブラウザからHTTPSアクセスを確認する。

```text
https://www.nobu-iac-lab.com
```

CLIで確認する場合:

```bash
curl -I https://www.nobu-iac-lab.com
```

## HTTPS接続確認

Webブラウザから以下へアクセスし、HTTPSでWebページが表示されることを確認した。

```text
https://www.nobu-iac-lab.com
```

これにより、以下の経路で通信できることを確認した。

```text
Client
  ↓ HTTPS 443
Route 53
  ↓
Application Load Balancer
  ↓ forward
Target Group sample-tg
  ↓ HTTP 3000
Web01 / Web02
```

## 学んだこと

- ACMでSSL/TLS証明書をリクエストできる
- ACM証明書はDNS検証で発行できる
- Route 53を使うと、ACMのDNS検証用CNAMEを自動化しやすい
- 証明書が利用可能になるには、状態が `ISSUED` になる必要がある
- ALBにHTTPS Listenerを作成するには、ACM証明書ARNが必要になる
- HTTPS ListenerのDefault actionでTarget Groupへforwardできる
- ALBではクライアントからのHTTPS通信を終端し、Webサーバー側へHTTPで転送できる
- Public DNS、ACM、ALB Listener、Target Groupが連携してHTTPS公開ができる

## 注意事項

このスクリプトでは、HTTP 80番ポートからHTTPS 443番ポートへのリダイレクトは設定していない。
HTTPアクセスをHTTPSへ統一したい場合は、HTTP ListenerのDefault actionをredirectに変更する。

ACM証明書は無料で利用できるため、毎回削除せず残して再利用する運用がしやすい。

ACM証明書はリージョンに注意する。
ALBで利用する証明書は、ALBと同じリージョンである `ap-northeast-1` に作成する必要がある。

DNS検証用CNAMEレコードは、証明書の更新にも利用されるため、基本的には削除しない。

## 削除時の注意

ALBを削除する場合、HTTPS ListenerもALBと一緒に削除される。

ACM証明書は再利用できるため、学習用の削除スクリプトでは削除しない方針とする。

DNS検証用CNAMEレコードも、証明書を維持する場合は削除しない。

証明書を完全に削除する場合は、先にその証明書を利用しているListenerやCloudFrontなどの関連付けを外す必要がある。

