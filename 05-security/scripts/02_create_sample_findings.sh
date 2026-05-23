#!/usr/bin/env bash
set -euo pipefail

##########################################
# GuardDuty Sample Findings Script
#
# 目的:
#   GuardDutyのサンプルFindingを生成し、Finding一覧と詳細を確認する。
#
# このスクリプトで行うこと:
#   1. AWS CLIの実行アカウントを確認する
#   2. GuardDuty Detector IDを取得する
#   3. サンプルFindingを生成する
#   4. Finding ID一覧を表示する
#   5. Finding詳細からType、Severity、Title、Resourceを確認する
#
# 注意:
#   サンプルFindingは実際の攻撃や侵害ではない。
#   GuardDutyの画面表示、CLI確認、調査観点の学習に使う。
##########################################

##########################################
# 基本設定
##########################################

# AWS CLIで使用するプロファイル
PROFILE="learning"

# GuardDutyを確認するリージョン
REGION="ap-northeast-1"

# 詳細表示するFinding件数
FINDING_LIMIT="10"

##########################################
# 表示用関数
##########################################

print_header() {
  echo "================================================"
  echo "$1"
  echo "================================================"
}

print_section() {
  echo
  echo "=== $1 ==="
}

##########################################
# 開始メッセージ
##########################################

print_header "Create GuardDuty Sample Findings"

echo "Profile : ${PROFILE}"
echo "Region  : ${REGION}"

##########################################
# Caller Identity確認
#
# 想定したAWSアカウントで実行しているか確認する。
# Findingはアカウント内のGuardDuty Detectorに紐づくため、
# profileとregionの確認が重要となる。
##########################################

print_section "Caller Identity"

aws sts get-caller-identity \
  --profile "${PROFILE}" \
  --output table

##########################################
# GuardDuty Detector ID取得
#
# GuardDutyの操作にはDetector IDが必要となる。
# Detectorが存在しない場合、このスクリプトでは作成しない。
# 先に01_guardduty_enable.shを実行する。
##########################################

print_section "Get GuardDuty Detector ID"

DETECTOR_ID="$(aws guardduty list-detectors \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --query 'DetectorIds[0]' \
  --output text)"

if [[ "${DETECTOR_ID}" == "None" || -z "${DETECTOR_ID}" ]]; then
  echo "GuardDuty Detector is not found."
  echo "Run 01_guardduty_enable.sh first."
  exit 1
fi

echo "Detector ID: ${DETECTOR_ID}"

##########################################
# サンプルFinding生成
#
# create-sample-findingsでGuardDutyのサンプルFindingを生成する。
# 生成されるFindingは学習用であり、実際の侵害ではない。
#
# サンプルFindingはGuardDutyコンソール上にも表示される。
# CLIとWebコンソールの両方で確認すると理解しやすい。
##########################################

print_section "Create Sample Findings"

aws guardduty create-sample-findings \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --detector-id "${DETECTOR_ID}"

echo "Sample findings created."

##########################################
# Finding ID一覧確認
#
# list-findingsでFinding IDの一覧を取得する。
# Findingの中身はlist-findingsではなくget-findingsで確認する。
##########################################

print_section "List Finding IDs"

FINDING_IDS="$(aws guardduty list-findings \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --detector-id "${DETECTOR_ID}" \
  --max-results "${FINDING_LIMIT}" \
  --query 'FindingIds' \
  --output text)"

if [[ -z "${FINDING_IDS}" || "${FINDING_IDS}" == "None" ]]; then
  echo "No findings found."
  echo "Wait a little and run this script again."
  exit 1
fi

echo "${FINDING_IDS}" | tr '\t' '\n'

##########################################
# Finding詳細確認
#
# get-findingsでFindingの詳細を確認する。
# ここではtable形式で、最初に見るべき項目だけを抽出する。
#
# Type:
#   検知内容の種類
#
# Severity:
#   重要度
#
# Title:
#   検知内容の概要
#
# ResourceType:
#   対象リソースの種類
##########################################

print_section "Show Finding Summary"

aws guardduty get-findings \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --detector-id "${DETECTOR_ID}" \
  --finding-ids ${FINDING_IDS} \
  --query 'Findings[].{Severity:Severity,Type:Type,Title:Title,ResourceType:Resource.ResourceType}' \
  --output table

##########################################
# Finding詳細JSON確認
#
# tableでは見えない詳細をJSONで確認する。
# 調査時はDescription、Resource、Service.Action、RemoteIpDetailsなどを見る。
##########################################

print_section "Show Finding Details JSON"

aws guardduty get-findings \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --detector-id "${DETECTOR_ID}" \
  --finding-ids ${FINDING_IDS} \
  --query 'Findings[].{
    Id:Id,
    Type:Type,
    Severity:Severity,
    Title:Title,
    Description:Description,
    Resource:Resource,
    ServiceAction:Service.Action,
    FirstSeen:Service.EventFirstSeen,
    LastSeen:Service.EventLastSeen
  }' \
  --output json

##########################################
# 次の作業メモ
##########################################

print_header "GuardDuty sample findings completed"

cat <<EOF
Detector ID:
  ${DETECTOR_ID}

Checked finding count:
  ${FINDING_LIMIT}

Next checks:
  aws guardduty list-findings \\
    --profile ${PROFILE} \\
    --region ${REGION} \\
    --detector-id ${DETECTOR_ID} \\
    --max-results ${FINDING_LIMIT}

  FINDING_IDS=\$(aws guardduty list-findings \\
    --profile ${PROFILE} \\
    --region ${REGION} \\
    --detector-id ${DETECTOR_ID} \\
    --max-results ${FINDING_LIMIT} \\
    --query 'FindingIds' \\
    --output text)

  aws guardduty get-findings \\
    --profile ${PROFILE} \\
    --region ${REGION} \\
    --detector-id ${DETECTOR_ID} \\
    --finding-ids \${FINDING_IDS} \\
    --output json

Look at:
  - Type
  - Severity
  - Title
  - Description
  - Resource
  - Service.Action
  - FirstSeen / LastSeen

Notes:
  - サンプルFindingは実際の侵害ではない。
  - Severityは重要度、Findingは検知結果を意味する。
  - 実務ではFindingを見た後、CloudTrail、VPC Flow Logs、Security Group、IAM、対象リソースを確認する。
EOF

