#!/bin/bash

set -euo pipefail

# ================================================================
# Create CloudWatch Dashboard
#
# このスクリプトは、日次ラボ環境で作成したAWSリソースの
# 主要メトリクスを一覧できるCloudWatch Dashboardを作成する。
#
# 目的:
#   - CloudWatch Alarmだけでなく、運用時に見るべきメトリクスを
#     1つの画面にまとめる。
#   - EC2 / ALB / Target Group / RDS / ElastiCache の状態を
#     CloudWatch Dashboardで俯瞰できるようにする。
#   - Terraform化する前に、CloudWatch Dashboardの構成要素と
#     メトリクス指定方法をAWS CLIで理解する。
#
# このスクリプトで作成するDashboard:
#   - nobu-iac-lab-dashboard
#
# 表示する主なメトリクス:
#   EC2:
#     - CPUUtilization
#     - StatusCheckFailed
#
#   ALB:
#     - RequestCount
#     - HTTPCode_ELB_5XX_Count
#     - HTTPCode_Target_5XX_Count
#     - TargetResponseTime
#
#   Target Group:
#     - HealthyHostCount
#     - UnHealthyHostCount
#
#   RDS:
#     - CPUUtilization
#     - FreeStorageSpace
#     - DatabaseConnections
#
#   ElastiCache:
#     - CPUUtilization
#     - CurrConnections
#
# 注意:
#   - Dashboardは同じ名前で再実行すると上書き更新される。
#   - EC2 InstanceId、ALB Dimension、TargetGroup Dimensionは
#     日次再構築で変わるため、スクリプト実行時に動的取得する。
#   - CloudWatch Dashboard自体はリソースの監視画面であり、
#     Alarm通知は行わない。
#   - Alarm通知は 01_create_alarms.sh と、後続のSNS設定で扱う。
#
# 前提:
#   - 01-aws-cli/scripts/All_Setup.sh によりAWSリソースが作成済みであること。
#   - Web EC2が sample-ec2-web01 / sample-ec2-web02 というNameタグで起動していること。
#   - ALB名が sample-elb であること。
#   - Target Group名が sample-tg であること。
#   - RDS DB Instance Identifier が sample-db であること。
#   - ElastiCache Replication Group ID が sample-elasticache であること。
#
# 実行例:
#   cd /Users/nobu/terraform-iac-lab/03-cloudwatch/scripts
#   chmod +x 02_create_dashboard.sh
#   ./02_create_dashboard.sh
#
# 確認例:
#   aws cloudwatch get-dashboard \
#     --profile learning \
#     --region ap-northeast-1 \
#     --dashboard-name nobu-iac-lab-dashboard
#
# マネジメントコンソール確認:
#   CloudWatch > Dashboards > nobu-iac-lab-dashboard
# ================================================================

PROFILE="learning"
REGION="ap-northeast-1"

PROJECT_NAME="nobu-iac-lab"
DASHBOARD_NAME="${PROJECT_NAME}-dashboard"

ALB_NAME="sample-elb"
TARGET_GROUP_NAME="sample-tg"
RDS_INSTANCE_ID="sample-db"
ELASTICACHE_REPLICATION_GROUP_ID="sample-elasticache"

echo "================================================"
echo "Create CloudWatch Dashboard"
echo "================================================"

echo "=== Caller Identity ==="
# 実行前にAWSアカウントを確認する。
# 誤ったprofileやアカウントにDashboardを作らないための安全確認。
aws sts get-caller-identity \
  --profile "${PROFILE}" \
  --output table

echo "=== Get EC2 instance IDs ==="
# Web EC2のInstanceIdをNameタグから取得する。
# 日次ラボではEC2を毎回作り直すため、InstanceIdは固定できない。
# そのため、CloudWatch Dashboardのメトリクス定義も毎回動的に作る。
WEB_INSTANCE_IDS=$(aws ec2 describe-instances \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --filters \
    "Name=tag:Name,Values=sample-ec2-web01,sample-ec2-web02" \
    "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

if [ -z "${WEB_INSTANCE_IDS}" ] || [ "${WEB_INSTANCE_IDS}" = "None" ]; then
  echo "ERROR: Running web EC2 instances were not found."
  echo "Please run All_Setup.sh first and check EC2 Name tags."
  exit 1
fi

echo "Web Instances:"
echo "  ${WEB_INSTANCE_IDS}"

# Dashboard本文はJSONで作成する。
# EC2メトリクスは台数分だけ配列要素を作る必要があるため、
# まずEC2 CPU用とStatusCheck用のmetrics配列を文字列として組み立てる。
#
# CloudWatch Dashboardのmetrics指定例:
#   [ "AWS/EC2", "CPUUtilization", "InstanceId", "i-xxxx" ]
#
# これは以下を意味する。
#   namespace  : AWS/EC2
#   metric name: CPUUtilization
#   dimension  : InstanceId = i-xxxx
EC2_CPU_METRICS=""
EC2_STATUS_METRICS=""

for INSTANCE_ID in ${WEB_INSTANCE_IDS}; do
  if [ -n "${EC2_CPU_METRICS}" ]; then
    EC2_CPU_METRICS="${EC2_CPU_METRICS},"
    EC2_STATUS_METRICS="${EC2_STATUS_METRICS},"
  fi

  EC2_CPU_METRICS="${EC2_CPU_METRICS}[ \"AWS/EC2\", \"CPUUtilization\", \"InstanceId\", \"${INSTANCE_ID}\" ]"
  EC2_STATUS_METRICS="${EC2_STATUS_METRICS}[ \"AWS/EC2\", \"StatusCheckFailed\", \"InstanceId\", \"${INSTANCE_ID}\" ]"
done

echo "=== Get ALB and Target Group dimensions ==="
# ALB系メトリクスでは、CloudWatch DimensionにARN全体ではなく、
# ARNの一部を指定する必要がある。
#
# LoadBalancer dimension:
#   app/sample-elb/xxxxxxxxxxxxxxxx
#
# TargetGroup dimension:
#   targetgroup/sample-tg/yyyyyyyyyyyyyyyy
#
# そのため、ELBv2 APIでARNを取得し、bashの文字列処理で
# CloudWatch用Dimension値に変換する。
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --names "${ALB_NAME}" \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text)

TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --names "${TARGET_GROUP_NAME}" \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text)

if [ -z "${ALB_ARN}" ] || [ "${ALB_ARN}" = "None" ]; then
  echo "ERROR: ALB not found: ${ALB_NAME}"
  exit 1
fi

if [ -z "${TARGET_GROUP_ARN}" ] || [ "${TARGET_GROUP_ARN}" = "None" ]; then
  echo "ERROR: Target Group not found: ${TARGET_GROUP_NAME}"
  exit 1
fi

# ARNから "loadbalancer/" より後ろを取り出す。
# 例:
#   arn:aws:elasticloadbalancing:...:loadbalancer/app/sample-elb/abc
#   -> app/sample-elb/abc
ALB_DIMENSION="${ALB_ARN#*loadbalancer/}"

# ARNから "targetgroup/" より後ろを取り出し、
# CloudWatch Dimension形式に合わせて "targetgroup/" を付け直す。
# 例:
#   arn:aws:elasticloadbalancing:...:targetgroup/sample-tg/def
#   -> targetgroup/sample-tg/def
TARGET_GROUP_DIMENSION="${TARGET_GROUP_ARN#*targetgroup/}"
TARGET_GROUP_DIMENSION="targetgroup/${TARGET_GROUP_DIMENSION}"

echo "ALB Dimension          : ${ALB_DIMENSION}"
echo "Target Group Dimension : ${TARGET_GROUP_DIMENSION}"

echo "=== Create dashboard body JSON ==="
# put-dashboard はJSON文字列を --dashboard-body に渡す必要がある。
#
# ここでは一時ファイルを使ってDashboard定義を作る。
# 一時ファイルにする理由:
#   - 長いJSONをAWS CLI引数に直接書くと読みにくい
#   - ダブルクォートのエスケープが複雑になる
#   - 後からDashboard定義を確認しやすい
#
# mktempで作成したファイルは、スクリプト終了時にtrapで削除する。
DASHBOARD_BODY_FILE=$(mktemp)
trap 'rm -f "${DASHBOARD_BODY_FILE}"' EXIT

# Dashboard Body JSONの構造については
# ../notes/02_cloudwatch_dashboard_setup.md を参照する。
cat > "${DASHBOARD_BODY_FILE}" <<EOF
{
  "widgets": [
    {
      "type": "text",
      "x": 0,
      "y": 0,
      "width": 24,
      "height": 3,
      "properties": {
        "markdown": "# ${PROJECT_NAME} CloudWatch Dashboard\\nEC2 / ALB / RDS / ElastiCache の主要メトリクスを一覧します。\\nAlarmは 01_create_alarms.sh で作成します。"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 3,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "EC2 CPUUtilization",
        "region": "${REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 300,
        "stat": "Average",
        "metrics": [
          ${EC2_CPU_METRICS}
        ],
        "yAxis": {
          "left": {
            "label": "Percent",
            "min": 0,
            "max": 100
          }
        }
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 3,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "EC2 StatusCheckFailed",
        "region": "${REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 60,
        "stat": "Maximum",
        "metrics": [
          ${EC2_STATUS_METRICS}
        ],
        "yAxis": {
          "left": {
            "label": "0=OK / 1=Failed",
            "min": 0,
            "max": 1
          }
        }
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 9,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "ALB RequestCount",
        "region": "${REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 300,
        "stat": "Sum",
        "metrics": [
          [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${ALB_DIMENSION}" ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 9,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "ALB 5xx Errors",
        "region": "${REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 300,
        "stat": "Sum",
        "metrics": [
          [ "AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", "${ALB_DIMENSION}" ],
          [ "AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", "${ALB_DIMENSION}" ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 15,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "Target Group HealthyHostCount",
        "region": "${REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 60,
        "stat": "Minimum",
        "metrics": [
          [ "AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", "${TARGET_GROUP_DIMENSION}", "LoadBalancer", "${ALB_DIMENSION}" ],
          [ "AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", "${TARGET_GROUP_DIMENSION}", "LoadBalancer", "${ALB_DIMENSION}" ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 15,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "ALB TargetResponseTime",
        "region": "${REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 300,
        "stat": "Average",
        "metrics": [
          [ "AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "${ALB_DIMENSION}" ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 21,
      "width": 8,
      "height": 6,
      "properties": {
        "title": "RDS CPUUtilization",
        "region": "${REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 300,
        "stat": "Average",
        "metrics": [
          [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "${RDS_INSTANCE_ID}" ]
        ],
        "yAxis": {
          "left": {
            "label": "Percent",
            "min": 0,
            "max": 100
          }
        }
      }
    },
    {
      "type": "metric",
      "x": 8,
      "y": 21,
      "width": 8,
      "height": 6,
      "properties": {
        "title": "RDS FreeStorageSpace",
        "region": "${REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 300,
        "stat": "Average",
        "metrics": [
          [ "AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", "${RDS_INSTANCE_ID}" ]
        ],
        "yAxis": {
          "left": {
            "label": "Bytes",
            "min": 0
          }
        }
      }
    },
    {
      "type": "metric",
      "x": 16,
      "y": 21,
      "width": 8,
      "height": 6,
      "properties": {
        "title": "RDS DatabaseConnections",
        "region": "${REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 300,
        "stat": "Average",
        "metrics": [
          [ "AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "${RDS_INSTANCE_ID}" ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 27,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "ElastiCache CPUUtilization",
        "region": "${REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 300,
        "stat": "Average",
        "metrics": [
          [ "AWS/ElastiCache", "CPUUtilization", "ReplicationGroupId", "${ELASTICACHE_REPLICATION_GROUP_ID}" ]
        ],
        "yAxis": {
          "left": {
            "label": "Percent",
            "min": 0,
            "max": 100
          }
        }
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 27,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "ElastiCache CurrConnections",
        "region": "${REGION}",
        "view": "timeSeries",
        "stacked": false,
        "period": 300,
        "stat": "Average",
        "metrics": [
          [ "AWS/ElastiCache", "CurrConnections", "ReplicationGroupId", "${ELASTICACHE_REPLICATION_GROUP_ID}" ]
        ]
      }
    },
    {
      "type": "text",
      "x": 0,
      "y": 33,
      "width": 24,
      "height": 4,
      "properties": {
        "markdown": "## 運用確認メモ\\n- EC2 StatusCheckFailed は基盤・OS寄りの死活監視です。\\n- ALB HealthyHostCount はWebアプリへHTTP到達できるかを見る監視です。\\n- RDS FreeStorageSpace はBytes単位です。\\n- 異常時は CloudWatch Logs の nginx / Puma ログも確認します。"
      }
    }
  ]
}
EOF

echo "=== Put CloudWatch Dashboard ==="
# put-dashboard はDashboardを作成または更新する。
# 既に同名Dashboardがある場合は、今回作成したJSON内容で上書きされる。
aws cloudwatch put-dashboard \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --dashboard-name "${DASHBOARD_NAME}" \
  --dashboard-body "file://${DASHBOARD_BODY_FILE}"

echo "=== Show dashboard information ==="
# 作成したDashboardの存在確認。
# DashboardArnが返れば作成または更新に成功している。
aws cloudwatch list-dashboards \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --query "DashboardEntries[?DashboardName=='${DASHBOARD_NAME}'].{DashboardName:DashboardName,LastModified:LastModified,Size:Size}" \
  --output table

echo "================================================"
echo "CloudWatch Dashboard creation completed."
echo
echo "Dashboard name:"
echo "  ${DASHBOARD_NAME}"
echo
echo "Management Console:"
echo "  CloudWatch > Dashboards > ${DASHBOARD_NAME}"
echo
echo "CLI check:"
echo "  aws cloudwatch get-dashboard \\"
echo "    --profile ${PROFILE} \\"
echo "    --region ${REGION} \\"
echo "    --dashboard-name ${DASHBOARD_NAME}"
echo
echo "Notes:"
echo "  - Dashboard is overwritten when this script is re-run."
echo "  - EC2 InstanceIds and ALB dimensions are updated each time."
echo "  - If some graphs show no data, wait a few minutes for metrics to arrive."
echo "================================================"

