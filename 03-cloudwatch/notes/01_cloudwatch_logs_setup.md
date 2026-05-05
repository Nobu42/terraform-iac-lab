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

## 今後の拡張

- ログ保持期間を設定する
- 5xxエラーをMetric Filter化する
- CloudWatch Alarmを作成する
- DashboardでEC2 / ALB / RDSを一覧化する
- CloudWatch Logs Insightsで検索できるようにする

