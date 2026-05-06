# CloudWatch Dashboard Setup

このメモでは、CloudWatch DashboardをAWS CLIで作成するために使う
Dashboard Body JSONの考え方を整理する。

## このメモの目的

CloudWatch Dashboardは、AWSマネジメントコンソール上では
グラフやテキストを画面に配置して作成する。

一方、AWS CLIでDashboardを作成する場合は、
Dashboard Bodyと呼ばれるJSONを `put-dashboard` コマンドへ渡す。

このラボでは、Dashboardを手作業で作るのではなく、
`03-cloudwatch/scripts/02_create_dashboard.sh` からDashboard Body JSONを生成し、
AWS CLIで作成する。

これにより、監視画面の構成もコードとして再作成できるようにする。

## Dashboard Bodyとは

Dashboard Bodyとは、CloudWatch Dashboardの画面構成を表すJSONである。

たとえば、以下のような情報をJSONで定義する。

- どのウィジェットを表示するか
- ウィジェットをどの位置に置くか
- ウィジェットのサイズをどうするか
- どのCloudWatchメトリクスを表示するか
- どのリージョンのメトリクスを見るか
- 平均値、最大値、合計値など、どの統計値で表示するか
- テキストウィジェットに何を書くか

AWS CLIでは、このJSONを `--dashboard-body` に渡す。

```bash
aws cloudwatch put-dashboard \
  --dashboard-name nobu-iac-lab-dashboard \
  --dashboard-body file://dashboard.json
```

`put-dashboard` は、Dashboardを作成または更新するコマンドである。

同じDashboard名で再実行した場合は、既存Dashboardが新しい内容で上書きされる。

## Dashboard Bodyの基本構造

Dashboard Bodyの基本形は以下の通り。

```json
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/EC2", "CPUUtilization", "InstanceId", "i-xxxxxxxxxxxxxxxxx" ]
        ],
        "region": "ap-northeast-1",
        "stat": "Average",
        "period": 300,
        "title": "EC2 CPUUtilization"
      }
    }
  ]
}
```

最上位には `widgets` という配列がある。

Dashboardに表示するグラフやテキストは、すべてこの `widgets` 配列の中に定義する。

## widgets

`widgets` は、Dashboardに表示する部品の一覧である。

1つのグラフ、1つのテキストブロックが、それぞれ1つのwidgetになる。

```json
"widgets": [
  {
    "type": "metric",
    "x": 0,
    "y": 0,
    "width": 12,
    "height": 6,
    "properties": {
      "title": "EC2 CPUUtilization"
    }
  }
]
```

## type

`type` はウィジェットの種類を表す。

よく使うものは以下の2つ。

```json
"type": "metric"
```

CloudWatchメトリクスをグラフ表示するウィジェット。

EC2 CPU、ALB 5xx、RDS接続数などを表示する。

```json
"type": "text"
```

Markdown形式の説明文を表示するウィジェット。

Dashboardの説明や運用メモを書くときに使う。

## x / y

`x` と `y` は、Dashboard上の表示位置を表す。

```json
"x": 0,
"y": 0
```

CloudWatch Dashboardは、横24マスのグリッドとして扱われる。

- `x`
  - 左から何マス目に配置するか
- `y`
  - 上から何マス目に配置するか

たとえば、以下は左上に配置するという意味。

```json
"x": 0,
"y": 0
```

右側に配置したい場合は、`x` を大きくする。

```json
"x": 12,
"y": 0
```

## width / height

`width` と `height` は、ウィジェットのサイズを表す。

```json
"width": 12,
"height": 6
```

CloudWatch Dashboardの横幅は24マスなので、`width: 12` は画面の半分の幅になる。

よく使う配置例:

```json
"x": 0,
"y": 0,
"width": 12,
"height": 6
```

左半分にグラフを表示する。

```json
"x": 12,
"y": 0,
"width": 12,
"height": 6
```

右半分にグラフを表示する。

```json
"x": 0,
"y": 0,
"width": 24,
"height": 3
```

横幅いっぱいにテキストを表示する。

## properties

`properties` は、ウィジェットの詳細設定を定義する場所である。

metricウィジェットでは、以下のような項目を書く。

```json
"properties": {
  "metrics": [
    [ "AWS/EC2", "CPUUtilization", "InstanceId", "i-xxxxxxxxxxxxxxxxx" ]
  ],
  "region": "ap-northeast-1",
  "view": "timeSeries",
  "stacked": false,
  "period": 300,
  "stat": "Average",
  "title": "EC2 CPUUtilization"
}
```

## metrics

`metrics` は、表示するCloudWatchメトリクスを指定する配列である。

基本形は以下。

```json
[ "Namespace", "MetricName", "DimensionName", "DimensionValue" ]
```

EC2 CPUUtilizationの例:

```json
[ "AWS/EC2", "CPUUtilization", "InstanceId", "i-xxxxxxxxxxxxxxxxx" ]
```

これは以下を意味する。

```text
Namespace:
  AWS/EC2

MetricName:
  CPUUtilization

Dimension:
  InstanceId = i-xxxxxxxxxxxxxxxxx
```

つまり、

```text
EC2のCPUUtilizationメトリクスのうち、
指定したInstanceIdの値を表示する
```

という意味になる。

## Namespace

Namespaceは、CloudWatchメトリクスの分類である。

主な例:

```text
AWS/EC2
AWS/ApplicationELB
AWS/RDS
AWS/ElastiCache
```

このラボでは以下を使う。

```text
EC2:
  AWS/EC2

ALB / Target Group:
  AWS/ApplicationELB

RDS:
  AWS/RDS

ElastiCache:
  AWS/ElastiCache
```

## MetricName

MetricNameは、表示するメトリクス名である。

例:

```text
CPUUtilization
StatusCheckFailed
RequestCount
HTTPCode_ELB_5XX_Count
HTTPCode_Target_5XX_Count
HealthyHostCount
UnHealthyHostCount
TargetResponseTime
FreeStorageSpace
DatabaseConnections
CurrConnections
```

`Namespace` と `MetricName` を組み合わせることで、何のメトリクスを見るかが決まる。

## Dimension

Dimensionは、同じメトリクス名の中から対象リソースを絞り込むためのキーと値である。

EC2の場合:

```json
[ "AWS/EC2", "CPUUtilization", "InstanceId", "i-xxxxxxxxxxxxxxxxx" ]
```

ここでは、

```text
InstanceId = i-xxxxxxxxxxxxxxxxx
```

がDimensionである。

RDSの場合:

```json
[ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "sample-db" ]
```

ここでは、

```text
DBInstanceIdentifier = sample-db
```

がDimensionである。

ALBの場合:

```json
[ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/sample-elb/xxxxxxxxxxxxxxxx" ]
```

ここでは、

```text
LoadBalancer = app/sample-elb/xxxxxxxxxxxxxxxx
```

がDimensionである。

つまり、CloudWatchメトリクスでは、

```text
MetricName:
  何を見るか

Dimension:
  どのリソースを見るか
```

という関係になる。

## ALBとTarget GroupのDimension

ALBやTarget GroupのCloudWatch Dimensionでは、ARN全体ではなくARNの一部を使う。

ALB ARNの例:

```text
arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:loadbalancer/app/sample-elb/abc123
```

CloudWatch Dashboardで使うLoadBalancer Dimension:

```text
app/sample-elb/abc123
```

Target Group ARNの例:

```text
arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:targetgroup/sample-tg/def456
```

CloudWatch Dashboardで使うTargetGroup Dimension:

```text
targetgroup/sample-tg/def456
```

このラボの `02_create_dashboard.sh` では、以下のようにARNからDimensionを取り出している。

```bash
ALB_DIMENSION="${ALB_ARN#*loadbalancer/}"

TARGET_GROUP_DIMENSION="${TARGET_GROUP_ARN#*targetgroup/}"
TARGET_GROUP_DIMENSION="targetgroup/${TARGET_GROUP_DIMENSION}"
```

`#*loadbalancer/` は、bashのパラメータ展開である。

```bash
${変数#パターン}
```

は、変数の先頭からパターンに一致する部分を削除する。

`*loadbalancer/` は、

```text
任意の文字列 + loadbalancer/
```

を意味する。

そのため、

```bash
ALB_DIMENSION="${ALB_ARN#*loadbalancer/}"
```

は、ALB ARNの先頭から `loadbalancer/` までを削除し、
CloudWatchで使うDimension値だけを取り出している。

## region

`region` は、どのリージョンのメトリクスを見るかを指定する。

```json
"region": "ap-northeast-1"
```

CloudWatchメトリクスはリージョン単位で管理される。

このラボでは東京リージョンを使っているため、`ap-northeast-1` を指定する。

## stat

`stat` は、メトリクスをどう集計して表示するかを指定する。

主な値:

```text
Average
Maximum
Minimum
Sum
```

使い分けの例:

```text
CPUUtilization:
  Average

StatusCheckFailed:
  Maximum

RequestCount:
  Sum

HTTPCode_ELB_5XX_Count:
  Sum

HealthyHostCount:
  Minimum

FreeStorageSpace:
  Average

DatabaseConnections:
  Average
```

CPU使用率は平均を見ることが多い。

StatusCheckFailedは、期間内に一度でも失敗していれば見つけたいのでMaximumを使う。

RequestCountや5xx件数は、期間内の合計件数を見るためSumを使う。

HealthyHostCountは、期間内で最も少なかった正常台数を見るためMinimumを使う。

## period

`period` は、何秒単位でメトリクスを集計するかを指定する。

```json
"period": 300
```

これは300秒、つまり5分単位で集計するという意味。

例:

```text
60:
  1分単位

300:
  5分単位
```

EC2 CPUやRDS CPUのような傾向を見るメトリクスは、5分単位で見ることが多い。

StatusCheckFailedやHealthyHostCountのような死活監視に近いメトリクスは、1分単位で見ると気づきやすい。

## view

`view` は、表示形式を指定する。

```json
"view": "timeSeries"
```

`timeSeries` は時系列グラフである。

時間の経過に沿ってメトリクスの変化を見る。

## stacked

`stacked` は、複数メトリクスを積み上げ表示するかどうかを指定する。

```json
"stacked": false
```

`false` の場合、複数の線グラフとして表示する。

EC2 web01 / web02 のCPU使用率を比較するときは、積み上げではなく線で比較したいため `false` にしている。

## yAxis

`yAxis` は、グラフの縦軸設定である。

CPU使用率の例:

```json
"yAxis": {
  "left": {
    "label": "Percent",
    "min": 0,
    "max": 100
  }
}
```

CPU使用率は0%から100%までなので、縦軸を固定しておくと見やすい。

StatusCheckFailedの例:

```json
"yAxis": {
  "left": {
    "label": "0=OK / 1=Failed",
    "min": 0,
    "max": 1
  }
}
```

StatusCheckFailedは0または1の値なので、縦軸を0から1にしておく。

## textウィジェット

Dashboardには、グラフだけでなくMarkdown形式のテキストも配置できる。

例:

```json
{
  "type": "text",
  "x": 0,
  "y": 0,
  "width": 24,
  "height": 3,
  "properties": {
    "markdown": "# nobu-iac-lab CloudWatch Dashboard\nEC2 / ALB / RDS / ElastiCache の主要メトリクスを一覧します。"
  }
}
```

このラボでは、Dashboardの先頭と末尾にtextウィジェットを配置し、
何を見る画面なのか、異常時にどこを確認するかをメモとして表示する。

## Webコンソールとの関係

CloudWatchコンソールでDashboardを作成した場合も、
内部的にはDashboard Body JSONとして管理されている。

コンソール上でDashboardを開き、編集画面からJSONソースを確認できる。

つまり、今回のスクリプトは以下の作業を自動化している。

1. WebコンソールでDashboardを作成する
2. グラフウィジェットを配置する
3. 対象メトリクスを選ぶ
4. 表示位置とサイズを調整する
5. テキストメモを追加する
6. Dashboardを保存する

これらをJSONで定義し、AWS CLIの `put-dashboard` で作成している。

## 一時ファイルを使う理由

`02_create_dashboard.sh` では、以下のように一時ファイルへJSONを書き出している。

```bash
DASHBOARD_BODY_FILE=$(mktemp)

cat > "${DASHBOARD_BODY_FILE}" <<EOF
{
  "widgets": [
    ...
  ]
}
EOF

aws cloudwatch put-dashboard \
  --dashboard-name "${DASHBOARD_NAME}" \
  --dashboard-body "file://${DASHBOARD_BODY_FILE}"
```

一時ファイルを使う理由は以下。

- Dashboard Body JSONが長いため、AWS CLI引数に直接書くと読みにくい
- ダブルクォートのエスケープが複雑になる
- JSONとしてまとまった形で確認しやすい
- `file://` 形式で渡す方がAWS CLIと相性がよい

## ヒアドキュメント

`cat <<EOF ... EOF` は、bashのヒアドキュメントである。

複数行の文字列をファイルへ書き込むときに使う。

```bash
cat > dashboard.json <<EOF
{
  "widgets": []
}
EOF
```

この場合、`dashboard.json` にJSON内容が書き込まれる。

このラボでは、Dashboard Body JSONの中にbash変数を埋め込みたいので、
`<<EOF` を使っている。

例:

```bash
"region": "${REGION}"
```

スクリプト実行時に、

```bash
REGION="ap-northeast-1"
```

が展開され、JSONには以下のように入る。

```json
"region": "ap-northeast-1"
```

## Terraform化との関係

TerraformでCloudWatch Dashboardを作る場合も、
基本的には同じDashboard Body JSONを使う。

Terraformでは `aws_cloudwatch_dashboard` リソースを使う。

例:

```hcl
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "nobu-iac-lab-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "EC2 CPUUtilization"
          region = "ap-northeast-1"
          stat   = "Average"
          period = 300

          metrics = [
            [ "AWS/EC2", "CPUUtilization", "InstanceId", "i-xxxxxxxxxxxxxxxxx" ]
          ]
        }
      }
    ]
  })
}
```

つまり、AWS CLIでDashboard Bodyを理解しておくと、
Terraform化するときにも役立つ。

## このラボでの位置づけ

このラボでは、以下の順番でCloudWatchを学習する。

1. CloudWatch Logsでnginx / Pumaログを収集する
2. CloudWatch Alarmで主要メトリクスの異常検知を作る
3. CloudWatch Dashboardで運用確認画面を作る
4. 後続でSNS通知やTerraform化を検討する

Dashboardは、監視対象を一覧で見るための画面である。

異常検知はAlarm、原因調査はLogs、全体把握はDashboardという役割分担で考える。

