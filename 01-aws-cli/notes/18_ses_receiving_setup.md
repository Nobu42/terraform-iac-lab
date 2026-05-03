# 18 SES Receiving Setup

## 目的

Amazon SESでメール受信設定を行い、受信したメールをS3バケットへ保存する。

この手順では、`inquiry@nobu-iac-lab.com` 宛のメールをAmazon SESで受信し、S3バケット `nobu-iac-lab-mailbox` にraw MIME形式で保存する。

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース: Amazon SES, Route 53, S3
- 前提:
  - `nobu-iac-lab.com` をRoute 53で管理していること
  - Public Hosted Zoneが作成済みであること
  - SES Domain Identity `nobu-iac-lab.com` が作成済みであること
  - IAMユーザーにSES、Route 53、S3を操作する権限があること

## 設計値

| 項目 | 値 |
| :--- | :--- |
| 受信ドメイン | nobu-iac-lab.com |
| 受信メールアドレス | inquiry@nobu-iac-lab.com |
| SESリージョン | ap-northeast-1 |
| Receipt Rule Set | sample-ruleset |
| Receipt Rule | sample-rule-inquiry |
| Rule Status | Enabled |
| Spam and virus scanning | Enabled |
| 保存先S3バケット | nobu-iac-lab-mailbox |
| 保存先プレフィックス | inbox/ |
| MXレコード | 10 inbound-smtp.ap-northeast-1.amazonaws.com |
| MX TTL | 300 |

## 構成

```text
External Mail Sender
  ↓
MX record
  ↓
Amazon SES inbound endpoint
  ↓
Receipt Rule Set: sample-ruleset
  ↓
Receipt Rule: sample-rule-inquiry
  ↓
S3Action
  ↓
s3://nobu-iac-lab-mailbox/inbox/
```

## スクリプト

- [17_ses_receiving_setup.sh](../scripts/17_ses_receiving_setup.sh)

## 実行コマンド

```bash
./17_ses_receiving_setup.sh
```

## 処理内容

このスクリプトでは以下を行う。

1. Public Hosted Zoneを取得する
2. 受信用S3バケット `nobu-iac-lab-mailbox` を作成する
3. S3バケットのPublic Access Blockを有効化する
4. S3バケットのACLを無効化する
5. SESがS3へメールを書き込めるようにBucket Policyを設定する
6. SES Receipt Rule Set `sample-ruleset` を作成する
7. SES Receipt Rule `sample-rule-inquiry` を作成する
8. 受信対象を `inquiry@nobu-iac-lab.com` に設定する
9. 受信メールをS3へ保存するS3Actionを設定する
10. Receipt Rule SetをActive化する
11. Route 53にMXレコードを作成する
12. S3に受信メールが保存されることを確認する

## 実AWSでの実行結果

S3バケットを作成した。

```text
Creating S3 bucket: nobu-iac-lab-mailbox
S3 bucket created: nobu-iac-lab-mailbox
```

SESがS3へ保存できるようにBucket Policyを設定した。

```text
Bucket policy configured for SES.
SES SourceArn: arn:aws:ses:ap-northeast-1:445405559057:receipt-rule-set/sample-ruleset:receipt-rule/sample-rule-inquiry
```

Receipt Rule Setを作成した。

```text
Receipt Rule Set not found. Creating: sample-ruleset
Receipt Rule Set created: sample-ruleset
```

Receipt Ruleを作成した。

```text
Receipt Rule not found. Creating: sample-rule-inquiry
Receipt Rule created: sample-rule-inquiry
```

Receipt Rule SetをActive化した。

```text
Active Receipt Rule Set: sample-ruleset
```

MXレコードを作成した。

```text
Route 53 Change ID: /change/C098190825M29SAVRAL48
MX record is INSYNC.
```

作成されたMXレコード:

| Name | Type | Value |
| :--- | :--- | :--- |
| nobu-iac-lab.com | MX | 10 inbound-smtp.ap-northeast-1.amazonaws.com |

## Receipt Rule確認

作成されたReceipt Ruleは以下の通り。

| 項目 | 値 |
| :--- | :--- |
| Rule Set | sample-ruleset |
| Rule | sample-rule-inquiry |
| Enabled | True |
| ScanEnabled | True |
| Recipient | inquiry@nobu-iac-lab.com |
| Action | S3Action |
| Bucket | nobu-iac-lab-mailbox |

## 確認コマンド

MXレコードを確認する。

```bash
dig MX nobu-iac-lab.com
```

Route 53上のMXレコードを確認する。

```bash
aws route53 list-resource-record-sets \
  --profile learning \
  --hosted-zone-id Z02886402CZFSQE5OSSQ \
  --query "ResourceRecordSets[?Name==\`nobu-iac-lab.com.\` && Type==\`MX\`]" \
  --output table
```

Receipt Rule Setを確認する。

```bash
aws ses describe-receipt-rule-set \
  --profile learning \
  --region ap-northeast-1 \
  --rule-set-name sample-ruleset \
  --query 'Rules[*].{Name:Name,Enabled:Enabled,Recipients:Recipients,ScanEnabled:ScanEnabled,Actions:Actions[*].S3Action.BucketName}' \
  --output table
```

受信メールがS3に保存されたか確認する。

```bash
aws s3 ls s3://nobu-iac-lab-mailbox/inbox/ \
  --profile learning
```

## 受信テスト結果

外部メールアドレスから `inquiry@nobu-iac-lab.com` 宛にメールを送信し、S3に保存されることを確認した。

```bash
aws s3 ls s3://nobu-iac-lab-mailbox/inbox/ \
  --profile learning
```

実行結果:

```text
2026-05-03 15:19:11        645 AMAZON_SES_SETUP_NOTIFICATION
2026-05-03 15:21:02      10459 262l543ta56skgkosnn7t7a2tc5ani3s705pl901
```

`AMAZON_SES_SETUP_NOTIFICATION` はSESがセットアップ時に保存する通知ファイルである。
`262l543ta56skgkosnn7t7a2tc5ani3s705pl901` が実際に受信したメールである。

受信メールの中身を確認する場合:

```bash
aws s3 cp s3://nobu-iac-lab-mailbox/inbox/262l543ta56skgkosnn7t7a2tc5ani3s705pl901 - \
  --profile learning
```

ローカルに保存して確認する場合:

```bash
aws s3 cp s3://nobu-iac-lab-mailbox/inbox/262l543ta56skgkosnn7t7a2tc5ani3s705pl901 ./received-mail.eml \
  --profile learning
```

`.eml` ファイルはraw MIME形式のメールであり、メールヘッダーや本文を確認できる。

## 学んだこと

- SESで独自ドメイン宛のメールを受信できる
- SESの受信処理にはReceipt Rule SetとReceipt Ruleが必要になる
- Receipt RuleをActiveなRule Setに含めることで受信処理が実行される
- MXレコードをSESの受信エンドポイントへ向けることで、ドメイン宛メールをSESへ配送できる
- S3Actionを使うと、受信メールをS3にraw MIME形式で保存できる
- SESがS3へ書き込むには、S3 Bucket Policyで `ses.amazonaws.com` に `s3:PutObject` を許可する必要がある
- `Recipients` にメールアドレスを指定すると、特定アドレス宛のメールだけを処理できる
- Spam and virus scanningを有効にすると、SES側で受信メールのスキャンを行える

## 注意事項

MXレコードを設定すると、`nobu-iac-lab.com` 宛のメール配送先がSESになる。

この構成は通常のメールボックスではない。
SES受信エンドポイントはIMAP/POP3サーバーではないため、メールクライアントで直接受信する用途には使えない。

受信メールはS3にraw MIME形式で保存される。
アプリケーションで本文や添付ファイルを利用する場合は、S3上のメールファイルを解析する処理が必要になる。

このスクリプトでは、受信対象を以下に限定している。

```text
inquiry@nobu-iac-lab.com
```

`admin@nobu-iac-lab.com` や `support@nobu-iac-lab.com` などを受信したい場合は、Receipt RuleのRecipientsを追加する。

## 削除時の注意

SES受信設定を削除する場合は、以下の順序で削除する。

1. Receipt Ruleを削除する
2. Receipt Rule Setを削除する、またはActive Rule Setを解除する
3. MXレコードを削除する
4. S3バケット内の受信メールを削除する
5. S3バケットを削除する

S3バケットは中身が残っていると削除できない。
削除前に以下で中身を確認する。

```bash
aws s3 ls s3://nobu-iac-lab-mailbox/inbox/ \
  --profile learning
```

受信メールには個人情報や本文内容が含まれる可能性があるため、GitHubへアップロードしない。

