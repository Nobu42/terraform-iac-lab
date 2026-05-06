# CloudWatch AWS CLI Reference

このメモは、CloudWatchをAWS CLIで操作するときの基本文法を整理したリファレンスです。

このラボでは、AWSマネジメントコンソールだけに頼らず、CloudWatch Logs、CloudWatch Alarm、CloudWatch DashboardをAWS CLIから作成、確認、削除できるようにします。

## 基本設定

このリポジトリでは、AWS CLIのprofileとregionを以下の前提で扱います。

```bash
PROFILE="learning"
REGION="ap-northeast-1"
```

コマンド実行時は、基本的に以下を指定します。

```bash
--profile learning
--region ap-northeast-1
```

AWSアカウント確認:

```bash
aws sts get-caller-identity \
  --profile learning \
  --output table
```

CloudWatchはリージョン単位のサービスです。

EC2、ALB、RDS、ElastiCacheが東京リージョンにある場合、CloudWatch Logs、Alarm、Dashboardも `ap-northeast-1` で確認します。

## CloudWatch Logs

CloudWatch Logsは、EC2やアプリケーションのログを集約して確認するサービスです。

このラボでは、CloudWatch Agentを使って、Web EC2上のnginx / PumaログをCloudWatch Logsへ送信します。

### Log Group一覧を確認する

```bash
aws logs describe-log-groups \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name-prefix /nobu-iac-lab \
  --output table
```

主なオプション:

- `logs describe-log-groups`
  - Log Groupの一覧を取得する。

- `--log-group-name-prefix`
  - 指定したprefixで始まるLog Groupだけを表示する。

- `--output table`
  - 人間が読みやすい表形式で表示する。

このラボのLog Group:

```text
/nobu-iac-lab/nginx/access
/nobu-iac-lab/nginx/error
/nobu-iac-lab/puma/stdout
/nobu-iac-lab/puma/stderr
```

### Log Groupを作成する

```bash
aws logs create-log-group \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout
```

すでに同名のLog Groupが存在する場合は、`ResourceAlreadyExistsException` になります。

スクリプトでは、存在していても止まらないように以下のように扱うことがあります。

```bash
aws logs create-log-group \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout \
  2>/dev/null || true
```

ただし、エラーを握りつぶす書き方なので、学習中はまず通常コマンドで実行し、エラー内容を確認する方が理解しやすいです。

### Log Groupの保持期間を設定する

```bash
aws logs put-retention-policy \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout \
  --retention-in-days 7
```

主なオプション:

- `put-retention-policy`
  - Log Groupのログ保持期間を設定する。

- `--retention-in-days`
  - ログを何日保持するか。

このラボでは、コストを抑えるため7日保持にしています。

保持期間を設定しない場合、CloudWatch Logsは無期限保持になります。

### Log Stream一覧を確認する

```bash
aws logs describe-log-streams \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout \
  --order-by LastEventTime \
  --descending \
  --output table
```

主なオプション:

- `--log-group-name`
  - 対象のLog Groupを指定する。

- `--order-by LastEventTime`
  - 最後にログイベントが届いた時刻で並べる。

- `--descending`
  - 新しい順に表示する。

CloudWatch Agent設定でLog Stream名にInstanceIdを使うと、`web01` / `web02` のログを区別できます。

例:

```text
i-0081b4b6ca6744e7d
i-06c87b24d8e2d35fc
```

### ログイベントを検索する

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout \
  --filter-pattern "Started GET" \
  --output table
```

主なオプション:

- `filter-log-events`
  - Log Group内のログイベントを検索する。

- `--filter-pattern`
  - 検索したい文字列やパターンを指定する。

Railsアクセスログ確認:

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout \
  --filter-pattern "Started GET" \
  --output table
```

CSRFエラー確認:

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout \
  --filter-pattern "InvalidAuthenticityToken" \
  --output table
```

nginx access log確認:

```bash
aws logs filter-log-events \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/nginx/access \
  --filter-pattern "ELB-HealthChecker" \
  --output table
```

### Log Groupを削除する

```bash
aws logs delete-log-group \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name /nobu-iac-lab/puma/stdout
```

注意:

Log Groupを削除すると、その中のLog Streamとログイベントも削除されます。

トラブル調査に必要なログも消えるため、日次cleanupでは削除するか残すかを方針として決めます。

このラボでは、通常は保持期間7日で残し、完全cleanupしたい場合だけ削除する方針です。

## CloudWatch Alarm

CloudWatch Alarmは、メトリクスが一定条件を満たしたときに状態を変化させる機能です。

Alarm状態:

```text
OK
ALARM
INSUFFICIENT_DATA
```

- `OK`
  - 監視条件上、異常ではない。

- `ALARM`
  - 設定したしきい値を満たし、異常状態と判断された。

- `INSUFFICIENT_DATA`
  - 判定に必要なメトリクスデータがまだ足りない。

作成直後のAlarmは `INSUFFICIENT_DATA` になることがあります。

### Alarm一覧を確認する

```bash
aws cloudwatch describe-alarms \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name-prefix nobu-iac-lab \
  --output table
```

主なオプション:

- `cloudwatch describe-alarms`
  - CloudWatch Alarmの一覧を取得する。

- `--alarm-name-prefix`
  - 指定したprefixで始まるAlarmだけを表示する。

### EC2 CPU Alarmを作成する

```bash
aws cloudwatch put-metric-alarm \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name "nobu-iac-lab-ec2-i-xxxxxxxxxxxxxxxxx-cpu-high" \
  --alarm-description "EC2 CPUUtilization is high" \
  --namespace "AWS/EC2" \
  --metric-name "CPUUtilization" \
  --dimensions "Name=InstanceId,Value=i-xxxxxxxxxxxxxxxxx" \
  --statistic "Average" \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 80 \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --treat-missing-data "notBreaching" \
  --no-actions-enabled
```

このAlarmの意味:

```text
対象:
  指定したEC2 InstanceId

見る値:
  CPUUtilization

集計:
  5分平均

条件:
  CPUUtilization >= 80

回数:
  2回連続

結果:
  約10分間CPU使用率が高い状態ならALARM
```

主なオプション:

- `put-metric-alarm`
  - Alarmを作成または更新する。

- `--alarm-name`
  - Alarm名。
  - AWSの固定ルールではなく、自分たちで決める。

- `--namespace`
  - メトリクスの分類。
  - EC2は `AWS/EC2`。

- `--metric-name`
  - 監視するメトリクス名。

- `--dimensions`
  - どのリソースのメトリクスかを指定する。

- `--statistic`
  - 平均、最大、最小、合計などの集計方法。

- `--period`
  - 1評価期間の秒数。

- `--evaluation-periods`
  - 何回分の評価期間を見て判定するか。

- `--threshold`
  - しきい値。

- `--comparison-operator`
  - メトリクス値としきい値の比較方法。

- `--treat-missing-data`
  - メトリクス欠損時の扱い。

- `--no-actions-enabled`
  - Alarm Actionを無効化する。
  - SNS通知などをまだ行わない場合に使う。

### EC2 StatusCheck Alarmを作成する

```bash
aws cloudwatch put-metric-alarm \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name "nobu-iac-lab-ec2-i-xxxxxxxxxxxxxxxxx-status-check-failed" \
  --alarm-description "EC2 StatusCheckFailed is detected" \
  --namespace "AWS/EC2" \
  --metric-name "StatusCheckFailed" \
  --dimensions "Name=InstanceId,Value=i-xxxxxxxxxxxxxxxxx" \
  --statistic "Maximum" \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 1 \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --treat-missing-data "notBreaching" \
  --no-actions-enabled
```

このAlarmは、基盤、EC2、OS寄りの死活監視です。

```text
StatusCheckFailed = 0
  正常

StatusCheckFailed = 1
  System Status Check または Instance Status Check が失敗
```

アプリケーションの死活は、ALB Target Groupの `HealthyHostCount` と組み合わせて確認します。

### ALB 5xx Alarmを作成する

```bash
aws cloudwatch put-metric-alarm \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name "nobu-iac-lab-alb-5xx-high" \
  --alarm-description "ALB 5xx errors are detected" \
  --namespace "AWS/ApplicationELB" \
  --metric-name "HTTPCode_ELB_5XX_Count" \
  --dimensions "Name=LoadBalancer,Value=app/sample-elb/xxxxxxxxxxxxxxxx" \
  --statistic "Sum" \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --treat-missing-data "notBreaching" \
  --no-actions-enabled
```

`HTTPCode_ELB_5XX_Count` は、ALB自身が返した5xxエラー数です。

アプリケーション側が返した5xxは、`HTTPCode_Target_5XX_Count` で確認します。

### Target Group HealthyHostCount Alarmを作成する

```bash
aws cloudwatch put-metric-alarm \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name "nobu-iac-lab-targetgroup-healthy-host-low" \
  --alarm-description "HealthyHostCount is less than expected" \
  --namespace "AWS/ApplicationELB" \
  --metric-name "HealthyHostCount" \
  --dimensions \
    "Name=TargetGroup,Value=targetgroup/sample-tg/xxxxxxxxxxxxxxxx" \
    "Name=LoadBalancer,Value=app/sample-elb/yyyyyyyyyyyyyyyy" \
  --statistic "Minimum" \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 2 \
  --comparison-operator "LessThanThreshold" \
  --treat-missing-data "breaching" \
  --no-actions-enabled
```

このラボはWeb EC2 2台構成のため、正常なTargetが2未満になったらALARMにします。

```text
HealthyHostCount = 2
  web01 / web02 が両方正常

HealthyHostCount = 1
  片方がunhealthy

HealthyHostCount = 0
  両方がunhealthy
```

### RDS Alarmを作成する

RDS CPU:

```bash
aws cloudwatch put-metric-alarm \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name "nobu-iac-lab-rds-cpu-high" \
  --namespace "AWS/RDS" \
  --metric-name "CPUUtilization" \
  --dimensions "Name=DBInstanceIdentifier,Value=sample-db" \
  --statistic "Average" \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 80 \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --treat-missing-data "notBreaching" \
  --no-actions-enabled
```

RDS空きストレージ:

```bash
aws cloudwatch put-metric-alarm \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name "nobu-iac-lab-rds-free-storage-low" \
  --namespace "AWS/RDS" \
  --metric-name "FreeStorageSpace" \
  --dimensions "Name=DBInstanceIdentifier,Value=sample-db" \
  --statistic "Average" \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 5368709120 \
  --comparison-operator "LessThanThreshold" \
  --treat-missing-data "notBreaching" \
  --no-actions-enabled
```

`FreeStorageSpace` はBytes単位です。

このラボではRDSの割り当てストレージを20GiBで作成しているため、残り5GiB、つまり約25%を下回ったら警告する設定にしています。

実務では固定値ではなく、DBサイズ、増加速度、対応に必要な時間を考慮して設計します。

RDS接続数:

```bash
aws cloudwatch put-metric-alarm \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name "nobu-iac-lab-rds-database-connections-high" \
  --namespace "AWS/RDS" \
  --metric-name "DatabaseConnections" \
  --dimensions "Name=DBInstanceIdentifier,Value=sample-db" \
  --statistic "Average" \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 80 \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --treat-missing-data "notBreaching" \
  --no-actions-enabled
```

### ElastiCache Alarmを作成する

ElastiCache CPU:

```bash
aws cloudwatch put-metric-alarm \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name "nobu-iac-lab-elasticache-cpu-high" \
  --namespace "AWS/ElastiCache" \
  --metric-name "CPUUtilization" \
  --dimensions "Name=ReplicationGroupId,Value=sample-elasticache" \
  --statistic "Average" \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 80 \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --treat-missing-data "notBreaching" \
  --no-actions-enabled
```

ElastiCache接続数:

```bash
aws cloudwatch put-metric-alarm \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name "nobu-iac-lab-elasticache-curr-connections-high" \
  --namespace "AWS/ElastiCache" \
  --metric-name "CurrConnections" \
  --dimensions "Name=ReplicationGroupId,Value=sample-elasticache" \
  --statistic "Average" \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 100 \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --treat-missing-data "notBreaching" \
  --no-actions-enabled
```

`CurrConnections` は、Redisノードに現在接続しているクライアント接続数です。

これはWebアプリのログインユーザー数ではなく、Railsアプリ、Puma、Redisクライアント、connection pool、運用接続などを含みます。

### Alarmを削除する

```bash
aws cloudwatch delete-alarms \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-names \
    nobu-iac-lab-alb-5xx-high \
    nobu-iac-lab-targetgroup-healthy-host-low
```

複数のAlarm名をまとめて指定できます。

スクリプトでは、prefixでAlarm名を取得してまとめて削除します。

```bash
ALARM_NAMES=$(aws cloudwatch describe-alarms \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name-prefix nobu-iac-lab \
  --query "MetricAlarms[].AlarmName" \
  --output text)
```

## CloudWatch Dashboard

CloudWatch Dashboardは、メトリクスやテキストを1つの画面にまとめる機能です。

AWS CLIでは、Dashboard Body JSONを `put-dashboard` に渡して作成します。

### Dashboardを作成する

```bash
aws cloudwatch put-dashboard \
  --profile learning \
  --region ap-northeast-1 \
  --dashboard-name nobu-iac-lab-dashboard \
  --dashboard-body file://dashboard.json
```

主なオプション:

- `put-dashboard`
  - Dashboardを作成または更新する。

- `--dashboard-name`
  - Dashboard名。

- `--dashboard-body`
  - Dashboard定義JSON。

同じDashboard名で再実行すると、既存Dashboardは上書き更新されます。

### Dashboardを確認する

```bash
aws cloudwatch get-dashboard \
  --profile learning \
  --region ap-northeast-1 \
  --dashboard-name nobu-iac-lab-dashboard
```

Dashboard一覧:

```bash
aws cloudwatch list-dashboards \
  --profile learning \
  --region ap-northeast-1 \
  --output table
```

特定Dashboardだけ確認:

```bash
aws cloudwatch list-dashboards \
  --profile learning \
  --region ap-northeast-1 \
  --query "DashboardEntries[?DashboardName=='nobu-iac-lab-dashboard']" \
  --output table
```

### Dashboardを削除する

```bash
aws cloudwatch delete-dashboards \
  --profile learning \
  --region ap-northeast-1 \
  --dashboard-names nobu-iac-lab-dashboard
```

## Dimension

Dimensionは、同じメトリクス名の中から対象リソースを絞り込むためのキーと値です。

発音は、単数形が `dimension`、カタカナでは「ディメンション」です。

複数形 `dimensions` は「ディメンションズ」です。

```text
MetricName:
  何を見るか

Dimension:
  どのリソースを見るか
```

EC2:

```text
MetricName: CPUUtilization
Dimension : InstanceId = i-xxxxxxxxxxxxxxxxx
```

RDS:

```text
MetricName: CPUUtilization
Dimension : DBInstanceIdentifier = sample-db
```

ALB:

```text
MetricName: RequestCount
Dimension : LoadBalancer = app/sample-elb/xxxxxxxxxxxxxxxx
```

Target Group:

```text
MetricName: HealthyHostCount
Dimension : TargetGroup = targetgroup/sample-tg/xxxxxxxxxxxxxxxx
            LoadBalancer = app/sample-elb/yyyyyyyyyyyyyyyy
```

## ALB / Target Group Dimensionの取り出し

ALBやTarget GroupのCloudWatch Dimensionでは、ARN全体ではなくARNの一部を使います。

ALB ARN:

```text
arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:loadbalancer/app/sample-elb/abc123
```

CloudWatchで使う値:

```text
app/sample-elb/abc123
```

bashでは以下のように取り出します。

```bash
ALB_DIMENSION="${ALB_ARN#*loadbalancer/}"
```

意味:

```text
${変数#パターン}
  変数の先頭から、パターンに一致した最短部分を削除する

*loadbalancer/
  任意の文字列 + loadbalancer/
```

つまり、ALB ARNの先頭から `loadbalancer/` までを削除し、CloudWatch Dimensionに必要な部分だけを残しています。

Target Group ARN:

```text
arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:targetgroup/sample-tg/def456
```

CloudWatchで使う値:

```text
targetgroup/sample-tg/def456
```

bashでは以下のように取り出します。

```bash
TARGET_GROUP_DIMENSION="${TARGET_GROUP_ARN#*targetgroup/}"
TARGET_GROUP_DIMENSION="targetgroup/${TARGET_GROUP_DIMENSION}"
```

一度 `sample-tg/def456` を取り出し、CloudWatch Dimension形式に合わせて `targetgroup/` を付け直しています。

## よく使うquery

AWS CLIの `--query` は、出力JSONから必要な部分だけを取り出すために使います。

Alarm名だけ取得:

```bash
aws cloudwatch describe-alarms \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name-prefix nobu-iac-lab \
  --query "MetricAlarms[].AlarmName" \
  --output text
```

Alarm名、状態、メトリクス名を表形式で取得:

```bash
aws cloudwatch describe-alarms \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name-prefix nobu-iac-lab \
  --query "MetricAlarms[].{AlarmName:AlarmName,StateValue:StateValue,MetricName:MetricName,Namespace:Namespace}" \
  --output table
```

Dashboard名だけ取得:

```bash
aws cloudwatch list-dashboards \
  --profile learning \
  --region ap-northeast-1 \
  --query "DashboardEntries[].DashboardName" \
  --output text
```

特定Dashboardの有無を確認:

```bash
aws cloudwatch list-dashboards \
  --profile learning \
  --region ap-northeast-1 \
  --query "DashboardEntries[?DashboardName=='nobu-iac-lab-dashboard'].DashboardName" \
  --output text
```

## このラボでのCloudWatch操作順

このラボでは、CloudWatchを以下の順番で扱います。

1. Web EC2のIAM RoleへCloudWatch Logs送信用権限を付与する
2. AnsibleでCloudWatch Agentをインストールする
3. CloudWatch Logsへnginx / Pumaログを送信する
4. Log GroupとLog Streamを確認する
5. CloudWatch LogsでRails/nginxログを検索する
6. CloudWatch Alarmを作成する
7. CloudWatch Dashboardを作成する
8. cleanup時にAlarm / Dashboardを削除する

## 面接での説明例

CloudWatch Logsについて:

```text
CloudWatch AgentをWeb EC2に導入し、nginx access/error logとPuma stdout/stderr logをCloudWatch Logsへ集約しました。
これにより、複数WebサーバーへSSHしなくても、Railsのリクエストログやnginxのエラーを横断的に確認できます。
```

CloudWatch Alarmについて:

```text
EC2のCPUとStatusCheck、ALBの5xx、Target GroupのHealthyHostCount、RDSのCPU、空き容量、接続数、ElastiCacheのCPUと接続数にAlarmを設定しました。
基盤、HTTP、DB、キャッシュの主要な運用監視項目を一通り確認できる構成にしています。
```

CloudWatch Dashboardについて:

```text
運用時に見るべきメトリクスをCloudWatch Dashboardにまとめました。
EC2、ALB、Target Group、RDS、ElastiCacheの状態を1画面で確認できるようにしています。
Dashboard Body JSONもAWS CLIで生成し、再作成できる形にしています。
```
