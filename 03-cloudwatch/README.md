# 03 CloudWatch

このディレクトリでは、AWS CLIとAnsibleで構築したRailsアプリケーション環境に対して、CloudWatchによるログ収集と監視を追加します。

まずはEC2上のnginx / PumaログをCloudWatch Logsへ集約し、アプリケーションの動作確認やトラブル調査に利用できる状態を作ります。

現在、CloudWatch Agentによるnginx / Pumaログ収集、主要メトリクスのCloudWatch Alarm作成、CloudWatch Dashboard作成まで確認済みです。

## 目的

- EC2上のログをCloudWatch Logsへ集約する
- web01 / web02 のログを同じ場所で確認できるようにする
- nginx / Puma / Railsのトラブルをログから追跡できるようにする
- メトリクス、アラーム、ダッシュボードを作成する
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

実施内容:

1. Web EC2のIAM RoleにCloudWatch Logs送信用権限を追加した
2. AnsibleでCloudWatch Agentをインストールした
3. CloudWatch Agent設定ファイルを配置した
4. CloudWatch Agentを起動、自動起動化した
5. CloudWatch Logsにログイベントが届くことを確認した

## Ansible Playbook

Ansible編に以下のPlaybookを追加しました。

```text
02-ansible/playbooks/09_cloudwatch_agent.yml
```

役割:

- CloudWatch Agentのインストール
- ログ収集設定ファイルの配置
- CloudWatch Agentの起動
- CloudWatch Agentの状態確認

日次再構築用の `site.yml` にも追加済みです。

```yaml
- import_playbook: 09_cloudwatch_agent.yml
```

## 確認済み

CloudWatch Agentは `web01` / `web02` の両方で起動済みです。

```text
status: running
configstatus: configured
version: 1.300064.2
```

Log Groupは以下を確認済みです。

```text
/nobu-iac-lab/nginx/access
/nobu-iac-lab/nginx/error
/nobu-iac-lab/puma/stdout
/nobu-iac-lab/puma/stderr
```

各Log Groupの保持期間は7日です。

`/nobu-iac-lab/puma/stdout` では、`web01` / `web02` それぞれのLog Streamが作成されることを確認しました。

```text
i-00a0a32ed5b654e95
i-0852dd2d2ec66f138
```

Puma stdoutでは、Railsのリクエストログを検索できることを確認しました。

```text
Started GET "/"
Started GET "/login"
Started GET "/users/new"
```

nginx access logでは、ALB Health Checkのアクセスログを確認しました。

```text
ELB-HealthChecker/2.0
```

CloudWatch Alarmは以下を確認済みです。

```text
nobu-iac-lab-ec2-<instance-id>-cpu-high
nobu-iac-lab-ec2-<instance-id>-status-check-failed
nobu-iac-lab-alb-5xx-high
nobu-iac-lab-targetgroup-healthy-host-low
nobu-iac-lab-rds-cpu-high
nobu-iac-lab-rds-free-storage-low
nobu-iac-lab-rds-database-connections-high
nobu-iac-lab-elasticache-cpu-high
nobu-iac-lab-elasticache-curr-connections-high
```

CloudWatch Dashboardは以下を確認済みです。

```text
nobu-iac-lab-dashboard
```

Dashboardには、EC2、ALB、Target Group、RDS、ElastiCacheの主要メトリクスを配置しています。

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

Alarm一覧:

```bash
aws cloudwatch describe-alarms \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name-prefix nobu-iac-lab \
  --output table
```

Dashboard確認:

```bash
aws cloudwatch get-dashboard \
  --profile learning \
  --region ap-northeast-1 \
  --dashboard-name nobu-iac-lab-dashboard
```
## 現在の到達点

- CloudWatch Agentをweb01 / web02へ導入
- nginx access/error logをCloudWatch Logsへ送信
- Puma stdout/stderr logをCloudWatch Logsへ送信
- Log Group保持期間を7日に設定
- site.ymlへCloudWatch Agent設定を追加
- EC2 CPU / StatusCheckのAlarmを作成
- ALB 5xx / Target Group HealthyHostCountのAlarmを作成
- RDS CPU / FreeStorageSpace / DatabaseConnectionsのAlarmを作成
- ElastiCache CPU / CurrConnectionsのAlarmを作成
- CloudWatch Dashboardを作成

## 今後の拡張

- SNS Topicとメール通知の追加
- CloudWatch Logs Metric Filterの追加
- CloudWatch Dashboardの表示項目調整
- cleanup_all.shへのCloudWatch Alarm / Dashboard削除処理追加検討
- 運用確認手順の整理

