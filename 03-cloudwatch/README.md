# 03 CloudWatch

このディレクトリでは、AWS CLIとAnsibleで構築したRailsアプリケーション環境に対して、CloudWatchによるログ収集と監視を追加します。

まずはEC2上のnginx / PumaログをCloudWatch Logsへ集約し、アプリケーションの動作確認やトラブル調査に利用できる状態を目指します。

## 目的

- EC2上のログをCloudWatch Logsへ集約する
- web01 / web02 のログを同じ場所で確認できるようにする
- nginx / Puma / Railsのトラブルをログから追跡できるようにする
- 後続でメトリクス、アラーム、ダッシュボードへ拡張する
- 運用保守で確認すべき項目を整理する

## 対象構成

CloudWatch Logs収集対象は、AnsibleでデプロイしたRails 7.2アプリケーション環境です。

```text
Route 53
  |
ACM / ALB
  |
web01 / web02
  |
nginx
  |
Puma
  |
Rails 7.2
  |
RDS / S3
```

## 収集対象ログ

まずは以下のログをCloudWatch Logsへ送信します。

| 種類 | パス | 用途 |
| :--- | :--- | :--- |
| nginx access log | `/var/log/nginx/access.log` | HTTPリクエスト、ステータスコード、ALBからのアクセス確認 |
| nginx error log | `/var/log/nginx/error.log` | nginx設定不備、upstream接続エラー、413などの確認 |
| Puma stdout log | `/var/www/nobu-iac-lab/log/puma.stdout.log` | Railsリクエストログ、Controller処理、CSRFエラーなどの確認 |
| Puma stderr log | `/var/www/nobu-iac-lab/log/puma.stderr.log` | Puma起動時エラー、例外出力の確認 |

## Log Group設計

CloudWatch Logsでは、以下のLog Groupを作成する方針です。

| Log Group | 対象 |
| :--- | :--- |
| `/nobu-iac-lab/nginx/access` | nginx access log |
| `/nobu-iac-lab/nginx/error` | nginx error log |
| `/nobu-iac-lab/puma/stdout` | Puma stdout log |
| `/nobu-iac-lab/puma/stderr` | Puma stderr log |

Log StreamにはEC2インスタンスIDやホスト名を含め、`web01` / `web02` のログを区別できるようにします。

## 実装方針

CloudWatch Logsへのログ転送にはCloudWatch Agentを利用します。

想定作業:

1. Web EC2のIAM RoleにCloudWatch Logs送信用権限を追加する
2. AnsibleでCloudWatch Agentをインストールする
3. CloudWatch Agent設定ファイルを配置する
4. CloudWatch Agentを起動、自動起動化する
5. CloudWatch Logsにログイベントが届くことを確認する

## Ansibleで追加予定のPlaybook

Ansible編に以下のPlaybookを追加する予定です。

```text
02-ansible/playbooks/09_cloudwatch_agent.yml
```

役割:

- CloudWatch Agentのインストール
- ログ収集設定ファイルの配置
- CloudWatch Agentの起動
- CloudWatch Agentの状態確認

## 確認観点

CloudWatch Logs設定後、以下を確認します。

- nginx access logがCloudWatch Logsへ送信されること
- nginx error logがCloudWatch Logsへ送信されること
- Puma stdout logがCloudWatch Logsへ送信されること
- Puma stderr logがCloudWatch Logsへ送信されること
- `web01` / `web02` のログを区別できること
- Railsログイン、投稿、画像アップロード時のログを検索できること
- 413エラーやCSRFエラーのような過去のトラブルをログ検索で追えること

## 確認コマンド例

Log Group一覧:

```bash
aws logs describe-log-groups \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name-prefix /nobu-iac-lab \
  --output table
```

Log Stream一覧:

```bash
aws logs describe-log-streams \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout \
  --order-by LastEventTime \
  --descending \
  --output table
```

ログイベント確認:

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout \
  --filter-pattern "InvalidAuthenticityToken" \
  --output table
```

## 今後の拡張

CloudWatch Logs確認後、以下へ進みます。

- EC2 CPU / StatusCheckの監視
- ALB Target Group HealthyHostCount / 5xxの監視
- RDS CPU / FreeStorageSpace / DatabaseConnectionsの監視
- ElastiCache CPU / memory / connectionの監視
- CloudWatch Alarm作成
- CloudWatch Dashboard作成
- ログ保持期間の設定
- 運用確認手順の整理

