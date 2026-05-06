#!/bin/bash

set -euo pipefail

# ================================================================
# Cleanup CloudWatch Resources
#
# このスクリプトは、日次ラボ環境で作成したCloudWatch関連リソースを
# 削除するためのスクリプト。
#
# 削除対象:
#   - CloudWatch Alarm
#   - CloudWatch Dashboard
#   - CloudWatch Logs Log Group
#
# 基本方針:
#   - Alarmは毎日作り直すため削除する。
#   - DashboardもEC2 InstanceIdやALB Dimensionが日次再構築で変わるため削除する。
#   - Log Groupは保持期間7日を設定しているため、通常は残してもよい。
#   - 完全cleanupしたい場合だけ、DELETE_LOG_GROUPS=true にしてLog Groupも削除する。
#
# 注意:
#   - CloudWatch Alarm / Dashboardは、EC2やALBを削除しても自動では消えない。
#   - 古いAlarmを残すと、存在しないInstanceIdやALB Dimensionを監視し続ける。
#   - 古いDashboardを残すと、削除済みリソースのメトリクスが表示対象として残る。
#   - Log Groupを削除すると、過去のnginx / Pumaログも削除される。
#
# 前提:
#   - 01_create_alarms.sh により、nobu-iac-lab prefixのAlarmが作成されていること。
#   - 02_create_dashboard.sh により、nobu-iac-lab-dashboard が作成されていること。
#   - 09_cloudwatch_agent.yml により、/nobu-iac-lab 配下のLog Groupが作成されていること。
#
# 実行例:
#   cd /Users/nobu/terraform-iac-lab/03-cloudwatch/scripts
#   chmod +x 03_cleanup_cloudwatch.sh
#   ./03_cleanup_cloudwatch.sh
#
# Log Groupも削除したい場合:
#   DELETE_LOG_GROUPS=true ./03_cleanup_cloudwatch.sh
# ================================================================

PROFILE="learning"
REGION="ap-northeast-1"

PROJECT_NAME="nobu-iac-lab"
DASHBOARD_NAME="${PROJECT_NAME}-dashboard"

# 通常はLog Groupを削除しない。
# CloudWatch Logsは保持期間7日を設定しているため、短期の調査ログとして残す。
#
# 完全cleanupしたい場合だけ、実行時に以下のように指定する。
#
#   DELETE_LOG_GROUPS=true ./03_cleanup_cloudwatch.sh
#
DELETE_LOG_GROUPS="${DELETE_LOG_GROUPS:-false}"

LOG_GROUPS=(
  "/nobu-iac-lab/nginx/access"
  "/nobu-iac-lab/nginx/error"
  "/nobu-iac-lab/puma/stdout"
  "/nobu-iac-lab/puma/stderr"
)

echo "================================================"
echo "Cleanup CloudWatch Resources"
echo "================================================"

echo "=== Caller Identity ==="
# 実行前にAWSアカウントを確認する。
# 誤ったprofileやアカウントでCloudWatchリソースを削除しないための安全確認。
aws sts get-caller-identity \
  --profile "${PROFILE}" \
  --output table

echo "=== Delete CloudWatch Alarms ==="
# Alarm名prefixで、今回のラボ用Alarmを取得する。
# EC2 InstanceIdは毎回変わるため、Alarm名を個別に固定せずprefixでまとめて取得する。
ALARM_NAMES=$(aws cloudwatch describe-alarms \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --alarm-name-prefix "${PROJECT_NAME}" \
  --query "MetricAlarms[].AlarmName" \
  --output text)

if [ -z "${ALARM_NAMES}" ] || [ "${ALARM_NAMES}" = "None" ]; then
  echo "No CloudWatch Alarms found with prefix: ${PROJECT_NAME}"
else
  echo "Deleting alarms:"
  for ALARM_NAME in ${ALARM_NAMES}; do
    echo "  ${ALARM_NAME}"
  done

  # delete-alarms は複数Alarm名をまとめて受け取れる。
  # ただし、一度に削除できる数には上限があるため、将来的にAlarm数が増えた場合は分割削除を検討する。
  aws cloudwatch delete-alarms \
    --profile "${PROFILE}" \
    --region "${REGION}" \
    --alarm-names ${ALARM_NAMES}
fi

echo "=== Delete CloudWatch Dashboard ==="
# Dashboardは同じ名前で再実行すると上書きされるが、
# 日次cleanupとしては削除しておくと、現在の環境に紐づくDashboardだけを残せる。
DASHBOARD_EXISTS=$(aws cloudwatch list-dashboards \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --query "DashboardEntries[?DashboardName=='${DASHBOARD_NAME}'].DashboardName" \
  --output text)

if [ -z "${DASHBOARD_EXISTS}" ] || [ "${DASHBOARD_EXISTS}" = "None" ]; then
  echo "Dashboard not found: ${DASHBOARD_NAME}"
else
  echo "Deleting dashboard: ${DASHBOARD_NAME}"

  aws cloudwatch delete-dashboards \
    --profile "${PROFILE}" \
    --region "${REGION}" \
    --dashboard-names "${DASHBOARD_NAME}"
fi

echo "=== Delete CloudWatch Log Groups ==="
if [ "${DELETE_LOG_GROUPS}" != "true" ]; then
  echo "Skipping Log Group deletion."
  echo "DELETE_LOG_GROUPS is set to: ${DELETE_LOG_GROUPS}"
  echo "Log Groups are kept because retention is configured."
else
  echo "DELETE_LOG_GROUPS=true"
  echo "Deleting Log Groups."

  for LOG_GROUP in "${LOG_GROUPS[@]}"; do
    echo "Checking Log Group: ${LOG_GROUP}"

    LOG_GROUP_EXISTS=$(aws logs describe-log-groups \
      --profile "${PROFILE}" \
      --region "${REGION}" \
      --log-group-name-prefix "${LOG_GROUP}" \
      --query "logGroups[?logGroupName=='${LOG_GROUP}'].logGroupName" \
      --output text)

    if [ -z "${LOG_GROUP_EXISTS}" ] || [ "${LOG_GROUP_EXISTS}" = "None" ]; then
      echo "  Not found: ${LOG_GROUP}"
    else
      echo "  Deleting: ${LOG_GROUP}"

      aws logs delete-log-group \
        --profile "${PROFILE}" \
        --region "${REGION}" \
        --log-group-name "${LOG_GROUP}"
    fi
  done
fi

echo "=== Show remaining CloudWatch Alarms ==="
aws cloudwatch describe-alarms \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --alarm-name-prefix "${PROJECT_NAME}" \
  --query "MetricAlarms[].{AlarmName:AlarmName,StateValue:StateValue}" \
  --output table

echo "=== Show remaining CloudWatch Dashboard ==="
aws cloudwatch list-dashboards \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --query "DashboardEntries[?DashboardName=='${DASHBOARD_NAME}'].{DashboardName:DashboardName,LastModified:LastModified}" \
  --output table

echo "=== Show CloudWatch Log Groups ==="
aws logs describe-log-groups \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --log-group-name-prefix "/nobu-iac-lab" \
  --query "logGroups[].{logGroupName:logGroupName,retentionInDays:retentionInDays,storedBytes:storedBytes}" \
  --output table

echo "================================================"
echo "CloudWatch cleanup completed."
echo
echo "Deleted:"
echo "  - CloudWatch Alarms with prefix: ${PROJECT_NAME}"
echo "  - CloudWatch Dashboard: ${DASHBOARD_NAME}"
echo
echo "Log Groups:"
if [ "${DELETE_LOG_GROUPS}" = "true" ]; then
  echo "  - Deleted /nobu-iac-lab Log Groups"
else
  echo "  - Kept /nobu-iac-lab Log Groups"
  echo "  - To delete them, run:"
  echo "      DELETE_LOG_GROUPS=true ./03_cleanup_cloudwatch.sh"
fi
echo "================================================"

