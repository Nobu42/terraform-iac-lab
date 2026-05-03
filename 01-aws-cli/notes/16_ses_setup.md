# 16 SES Setup

## 目的

AWS CLIでAmazon SESの送信用設定を行う。

この手順では、独自ドメイン `nobu-iac-lab.com` をSESのDomain Identityとして作成し、DKIM、SPF、DMARCのDNSレコードをRoute 53に登録する。
また、SES sandbox環境で送信テストを行うため、個人メールアドレス `nobu4071@icloud.com` をEmail Address Identityとして作成する。

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース: Amazon SES, Route 53
- 前提:
  - `nobu-iac-lab.com` をRoute 53で管理していること
  - Public Hosted Zoneが作成済みであること
  - IAMユーザーにSESとRoute 53を操作する権限があること

## 設計値

| 項目 | 値 |
| :--- | :--- |
| SESリージョン | ap-northeast-1 |
| Domain Identity | nobu-iac-lab.com |
| DKIM | Easy DKIM |
| DKIM鍵長 | RSA_2048_BIT |
| DKIM署名 | Enabled |
| SPF | v=spf1 include:amazonses.com ~all |
| DMARC | v=DMARC1; p=none; rua=mailto:nobu4071@icloud.com |
| Email Address Identity | nobu4071@icloud.com |

## SES Identity設計

| Identity | 種別 | 用途 |
| :--- | :--- | :--- |
| nobu-iac-lab.com | Domain Identity | `no-reply@nobu-iac-lab.com` などの送信元ドメインとして利用 |
| nobu4071@icloud.com | Email Address Identity | SES sandbox中の送信テスト先として利用 |

## DNS設計

| レコード | タイプ | 用途 |
| :--- | :--- | :--- |
| DKIM CNAME | CNAME | SESが送信メールにDKIM署名するためのドメイン認証 |
| SPF TXT | TXT | SESからの送信を許可する送信元認証 |
| DMARC TXT | TXT | SPF/DKIMの認証結果に対する扱いを受信側へ伝える |

## スクリプト

- [16_ses_setup.sh](../scripts/16_ses_setup.sh)

## 実行コマンド

```bash
./16_ses_setup.sh
```

## 処理内容

このスクリプトでは以下を行う。

1. Public Hosted Zoneを取得する
2. SES Domain Identity `nobu-iac-lab.com` を作成する
3. DKIM署名を有効化する
4. SESが発行したDKIMトークンを取得する
5. Route 53にDKIM CNAMEレコードを作成する
6. Route 53にSPF TXTレコードを作成する
7. Route 53にDMARC TXTレコードを作成する
8. SES Email Address Identity `nobu4071@icloud.com` を作成する
9. SES IdentityとDNSレコードの状態を確認する

## 実AWSでの実行結果

SES Domain Identityを作成した。

```text
SES Domain Identity created: nobu-iac-lab.com
DKIM signing enabled.
```

SESが発行したDKIMトークンを取得した。

```text
DKIM Tokens:
  2qwrcp6ugzjy3gwurr2tll46fhyzdmct
  5zzrhtyv4pe37ebhphrsyrtlwmytisvd
  bztr5lymeg6aja2ivpjnm6nu65xtzvvc
```

Route 53にSES関連DNSレコードを作成した。

```text
Route 53 Change ID: /change/C08300103TWZ9GLS4JQLE
DNS records are INSYNC.
```

Email Address Identityを作成し、確認メールを送信した。

```text
Verification email sent to: nobu4071@icloud.com
Please open the email and click the verification link.
```

実行直後のSES Domain Identity状態:

| IdentityType | DkimStatus | SigningEnabled | VerifiedForSendingStatus |
| :--- | :--- | :--- | :--- |
| DOMAIN | PENDING | True | False |

実行直後のEmail Address Identity状態:

| IdentityType | VerifiedForSendingStatus |
| :--- | :--- |
| EMAIL_ADDRESS | False |

## 作成されたDNSレコード

SPFレコード:

```text
nobu-iac-lab.com. TXT "v=spf1 include:amazonses.com ~all"
```

DMARCレコード:

```text
_dmarc.nobu-iac-lab.com. TXT "v=DMARC1; p=none; rua=mailto:nobu4071@icloud.com"
```

DKIM CNAMEレコード:

```text
2qwrcp6ugzjy3gwurr2tll46fhyzdmct._domainkey.nobu-iac-lab.com. CNAME 2qwrcp6ugzjy3gwurr2tll46fhyzdmct.dkim.amazonses.com
5zzrhtyv4pe37ebhphrsyrtlwmytisvd._domainkey.nobu-iac-lab.com. CNAME 5zzrhtyv4pe37ebhphrsyrtlwmytisvd.dkim.amazonses.com
bztr5lymeg6aja2ivpjnm6nu65xtzvvc._domainkey.nobu-iac-lab.com. CNAME bztr5lymeg6aja2ivpjnm6nu65xtzvvc.dkim.amazonses.com
```

## 確認コマンド

SES Domain Identityの状態を確認する。

```bash
aws sesv2 get-email-identity \
  --profile learning \
  --region ap-northeast-1 \
  --email-identity nobu-iac-lab.com \
  --query '{
    IdentityType:IdentityType,
    VerifiedForSendingStatus:VerifiedForSendingStatus,
    DkimStatus:DkimAttributes.Status,
    SigningEnabled:DkimAttributes.SigningEnabled
  }' \
  --output table
```

SES Email Address Identityの状態を確認する。

```bash
aws sesv2 get-email-identity \
  --profile learning \
  --region ap-northeast-1 \
  --email-identity nobu4071@icloud.com \
  --query '{
    IdentityType:IdentityType,
    VerifiedForSendingStatus:VerifiedForSendingStatus
  }' \
  --output table
```

Route 53に登録したSES関連レコードを確認する。

```bash
aws route53 list-resource-record-sets \
  --profile learning \
  --hosted-zone-id Z02886402CZFSQE5OSSQ \
  --query "ResourceRecordSets[?contains(Name, \`_domainkey.nobu-iac-lab.com.\`) || Name==\`nobu-iac-lab.com.\` || Name==\`_dmarc.nobu-iac-lab.com.\`]" \
  --output table
```

DNSレコードを直接確認する。

```bash
dig TXT nobu-iac-lab.com
dig TXT _dmarc.nobu-iac-lab.com
dig CNAME 2qwrcp6ugzjy3gwurr2tll46fhyzdmct._domainkey.nobu-iac-lab.com
dig CNAME 5zzrhtyv4pe37ebhphrsyrtlwmytisvd._domainkey.nobu-iac-lab.com
dig CNAME bztr5lymeg6aja2ivpjnm6nu65xtzvvc._domainkey.nobu-iac-lab.com
```

## 検証待ちについて

スクリプト実行直後は、以下のように表示されることがある。

```text
DkimStatus: PENDING
VerifiedForSendingStatus: False
```

これは異常ではない。

`DkimStatus: PENDING` は、Route 53にDKIM CNAMEを作成した直後で、SES側の検証がまだ完了していない状態を示す。
DNS反映後、SESがレコードを確認できると `SUCCESS` になる。

`Email Address Identity` の `VerifiedForSendingStatus: False` は、確認メールのリンクをまだクリックしていない状態を示す。
`nobu4071@icloud.com` に届いたAWSからの確認メールを開き、リンクをクリックすると検証が完了する。

## 学んだこと

- SESでは送信元として利用するドメインをDomain Identityとして認証する
- SES sandbox環境では、送信先メールアドレスも検証済みである必要がある
- DKIM CNAMEをRoute 53に登録することで、SESがドメイン所有を確認できる
- SPF TXTを設定することで、SESからの送信を許可できる
- DMARC TXTを設定することで、SPF/DKIMの認証結果に対する扱いを受信側へ伝えられる
- `p=none` はメールを拒否せず、まずは認証状況を確認するためのDMARC設定である
- MXレコードはメール受信用の設定であり、送信用SES設定とは分けて考える

## 注意事項

このスクリプトではMXレコードは作成しない。
MXレコードはメール受信に関わるため、SES受信設定用の別スクリプトで扱う。

SMTP認証用IAMユーザーやSMTPパスワードは、このスクリプトでは作成しない。
SMTP認証情報は秘密情報であり、GitHubに載せてはいけないため、別手順で安全に管理する。

SESがsandbox状態の場合、送信元と送信先の両方が検証済みでないとメール送信できない。
任意の宛先へ送信するには、SES production access申請が必要になる。

## 削除時の注意

SES Domain Identityを削除すると、DKIM検証や送信元ドメイン認証も利用できなくなる。
学習用で継続利用する場合は、削除せず残しておく方がよい。

DKIM CNAMEレコードは、SESのドメイン検証とDKIM署名に必要なため、Domain Identityを維持する場合は削除しない。

SPF、DMARCレコードもメール送信の信頼性に関わるため、ドメインを継続利用する場合は削除しない。

