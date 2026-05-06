# 01 CloudWatch Logs Setup

## 目的

EC2上のnginx / PumaログをCloudWatch Logsへ送信し、複数Webサーバーのログを一元的に確認できるようにする。

これにより、SSHで各EC2へ入らなくても、Railsのログイン、投稿、画像アップロード、nginxのエラーなどをCloudWatch Logsから確認できるようにする。

## 背景

AnsibleでRails 7.2アプリケーションを `web01` / `web02` にデプロイした。

動作確認では、以下のようなログ調査をEC2上で行った。

```bash
ssh web01
sudo tail -n 120 /var/www/nobu-iac-lab/log/puma.stdout.log
sudo journalctl -u puma-nobu-iac-lab -f
```

単体調査ではこれで対応できるが、Web EC2が複数台ある場合、各EC2へSSHしてログを確認するのは手間がかかる。

そのため、CloudWatch Logsへログを集約し、AWS ConsoleやAWS CLIから横断的に検索できるようにする。

## 収集対象

| ログ | パス | 確認したい内容 |
| :--- | :--- | :--- |
| nginx access log | `/var/log/nginx/access.log` | アクセス元、リクエスト、ステータスコード |
| nginx error log | `/var/log/nginx/error.log` | nginxエラー、upstream接続エラー、413など |
| Puma stdout log | `/var/www/nobu-iac-lab/log/puma.stdout.log` | Railsリクエストログ、Controller処理、CSRFエラー |
| Puma stderr log | `/var/www/nobu-iac-lab/log/puma.stderr.log` | Puma起動エラー、標準エラー出力 |

## Log Group

CloudWatch Logsでは以下のLog Groupを利用する。

```text
/nobu-iac-lab/nginx/access
/nobu-iac-lab/nginx/error
/nobu-iac-lab/puma/stdout
/nobu-iac-lab/puma/stderr
```

## Log Stream

Log StreamはEC2インスタンスごとに分ける。

候補:

```text
{instance_id}
{hostname}
{instance_id}/{filename}
```

まずはCloudWatch Agentの標準変数を使い、EC2インスタンスIDで識別する方針とする。

## IAM権限

CloudWatch AgentがCloudWatch Logsへログを送信するには、Web EC2のIAM RoleにCloudWatch Logs書き込み権限が必要になる。

候補:

```text
CloudWatchAgentServerPolicy
```

現在のWeb EC2用IAM Roleに必要な権限を追加する方針とする。

## CloudWatch Agent

ログ収集にはCloudWatch Agentを利用する。

Ansibleで以下を行う。

1. CloudWatch Agentをインストールする
2. 設定ファイルを配置する
3. Agentを起動する
4. systemdで自動起動を有効化する
5. Agent状態を確認する

## Ansible Playbook案

追加予定:

```text
02-ansible/playbooks/09_cloudwatch_agent.yml
```

主なタスク:

- CloudWatch Agentパッケージ導入
- `/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json` 配置
- CloudWatch Agent設定反映
- `amazon-cloudwatch-agent` service起動
- Log Group送信確認

## 確認コマンド

Log Group確認:

```bash
aws logs describe-log-groups \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name-prefix /nobu-iac-lab \
  --output table
```

Log Stream確認:

```bash
aws logs describe-log-streams \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout \
  --order-by LastEventTime \
  --descending \
  --output table
```

ログ検索:

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout \
  --filter-pattern "POST /session" \
  --output table
```

CSRFエラー検索:

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout \
  --filter-pattern "InvalidAuthenticityToken" \
  --output table
```

## 動作確認シナリオ

CloudWatch Logs設定後、以下を行う。

1. ブラウザで `https://www.nobu-iac-lab.com` にアクセスする
2. ログインする
3. 投稿する
4. 画像付き投稿を行う
5. CloudWatch Logsでnginx access logを確認する
6. CloudWatch LogsでPuma stdout logを確認する
7. `web01` / `web02` のどちらで処理されたか確認する

## 当初の拡張予定

- ログ保持期間を設定する
- 5xxエラーをMetric Filter化する
- CloudWatch Alarmを作成する
- DashboardでEC2 / ALB / RDSを一覧化する
- CloudWatch Logs Insightsで検索できるようにする

## 実行結果

`09_cloudwatch_agent.yml` を実行し、CloudWatch Agentの導入とログ送信を確認した。

実行コマンド:

```bash
cd /Users/nobu/terraform-iac-lab/02-ansible
ansible-playbook playbooks/09_cloudwatch_agent.yml
```

実行結果:

```text
web01: failed=0
web02: failed=0
CloudWatch Agent status: running
configstatus: configured
version: 1.300064.2
```

途中で発生した権限エラー:

```text
AccessDeniedException: not authorized to perform: logs:CreateLogGroup
```

原因:

起動中のWeb EC2に関連付いているIAM Role `sample-role-web` に、CloudWatch Logs送信用の権限がまだ付与されていなかった。

対応:

`11_s3_setup.sh` を修正し、Web EC2用IAM Roleに以下のAWS管理ポリシーを追加した。

```text
CloudWatchAgentServerPolicy
```

既存EC2へ反映するため、以下を再実行した。

```bash
cd /Users/nobu/terraform-iac-lab/01-aws-cli/scripts
./11_s3_setup.sh
```

次に発生した競合エラー:

```text
OperationAbortedException: A conflicting operation is currently in progress against this resource.
```

原因:

`web01` / `web02` が同じLog Groupに対して同時に `put-retention-policy` を実行し、CloudWatch Logs側で競合した。

対応:

Log Group作成と保持期間設定は全EC2で実行する必要がないため、Ansibleの該当タスクに `run_once: true` を設定した。

```yaml
run_once: true
```

## 確認結果

Log Group一覧:

```bash
aws logs describe-log-groups \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name-prefix /nobu-iac-lab \
  --output table
```

確認できたLog Group:

```text
/nobu-iac-lab/nginx/access
/nobu-iac-lab/nginx/error
/nobu-iac-lab/puma/stdout
/nobu-iac-lab/puma/stderr
```

保持期間:

```text
retentionInDays: 7
```

Puma stdoutのLog Stream確認:

```bash
aws logs describe-log-streams \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout \
  --order-by LastEventTime \
  --descending \
  --output table
```

確認できたLog Stream:

```text
i-00a0a32ed5b654e95
i-0852dd2d2ec66f138
```

Puma stdoutログ検索:

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout \
  --filter-pattern "Started GET" \
  --output table
```

確認できたログ:

```text
Started GET "/"
Started GET "/login"
Started GET "/users/new"
```

nginx accessログ検索:

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/nginx/access \
  --limit 10 \
  --output table
```

確認できたログ:

```text
ELB-HealthChecker/2.0
```

## 学んだこと

CloudWatch Agentを導入するだけではログは送信できず、EC2に付与されたIAM RoleへCloudWatch Logs送信用権限が必要になる。

また、Log Groupのように複数EC2で共有するAWSリソースをAnsibleから操作する場合、全ホストで同時に実行すると競合することがある。

共有リソースの作成や保持期間設定は `run_once: true` で1回だけ実行する方が安全である。

## site.ymlでの一括実行確認

CloudWatch Agent単体の動作確認後、日次再構築用の `site.yml` に `09_cloudwatch_agent.yml` を追加した。

```yaml
- import_playbook: 01_ping.yml
- import_playbook: 04_nginx.yml
- import_playbook: 08_sample_app_rails72.yml
- import_playbook: 09_cloudwatch_agent.yml
```

`All_Setup.sh` でAWSリソースを作成した後、ローカル実行用スクリプトから `site.yml` を実行し、RailsアプリケーションとCloudWatch Agentをまとめて設定できることを確認した。

確認コマンド:

```bash
curl -I https://www.nobu-iac-lab.com
```

確認結果:

```text
HTTP/2 200
server: nginx/1.28.3
strict-transport-security: max-age=63072000; includeSubDomains
```

CloudWatch Logs確認:

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout \
  --filter-pattern "Started GET" \
  --output table
```

確認できたログ:

```text
Started GET "/"
Started GET "/login"
Started GET "/users/new"
```

これにより、`site.yml` だけでRailsアプリケーションの起動とCloudWatch Logs収集まで再現できることを確認した。

## 後続のAlarm / Dashboard作成確認

CloudWatch Logs収集確認後、主要メトリクスのAlarmとDashboardもAWS CLIスクリプトで作成した。

作成スクリプト:

```text
03-cloudwatch/scripts/01_create_alarms.sh
03-cloudwatch/scripts/02_create_dashboard.sh
```

Alarm作成では、EC2、ALB、Target Group、RDS、ElastiCacheの主要メトリクスを対象にした。

確認できたAlarm:

```text
nobu-iac-lab-alb-5xx-high
nobu-iac-lab-ec2-<instance-id>-cpu-high
nobu-iac-lab-ec2-<instance-id>-status-check-failed
nobu-iac-lab-elasticache-cpu-high
nobu-iac-lab-elasticache-curr-connections-high
nobu-iac-lab-rds-cpu-high
nobu-iac-lab-rds-database-connections-high
nobu-iac-lab-rds-free-storage-low
nobu-iac-lab-targetgroup-healthy-host-low
```

作成直後のAlarmは、メトリクス評価に必要なデータがまだ揃っていないため `INSUFFICIENT_DATA` になることがある。

Dashboard作成では、以下のDashboardを作成した。

```text
nobu-iac-lab-dashboard
```

`put-dashboard` の実行結果で `DashboardValidationMessages` が空配列になり、Dashboard Body JSONに検証エラーがないことを確認した。

```json
{
  "DashboardValidationMessages": []
}
```

Dashboardには、以下のメトリクスを配置した。

- EC2 CPUUtilization
- EC2 StatusCheckFailed
- ALB RequestCount
- ALB 5xx
- Target Group HealthyHostCount / UnHealthyHostCount
- ALB TargetResponseTime
- RDS CPUUtilization
- RDS FreeStorageSpace
- RDS DatabaseConnections
- ElastiCache CPUUtilization
- ElastiCache CurrConnections
