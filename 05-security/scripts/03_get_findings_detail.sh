#!/usr/bin/env bash
set -euo pipefail

##########################################
# GuardDuty Finding Detail Script
#
# 目的:
#   GuardDuty Findingを1件選び、詳細確認に必要な項目を見やすく表示する。
#
# このスクリプトで行うこと:
#   1. AWS CLIの実行アカウントを確認する
#   2. GuardDuty Detector IDを取得する
#   3. Severityが高いFindingを1件取得する
#   4. Findingの基本情報を表示する
#   5. 対象リソースと検知アクションを表示する
#   6. 初動調査で見る観点を表示する
#
# 注意:
#   サンプルFindingは実際の攻撃や侵害ではない。
#   このスクリプトは、Finding確認後の調査観点を学ぶために使う。
##########################################

##########################################
# 基本設定
##########################################

# AWS CLIで使用するプロファイル
PROFILE="learning"

# GuardDutyを確認するリージョン
REGION="ap-northeast-1"

# Finding一覧から取得する最大件数
FINDING_SEARCH_LIMIT="50"

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

print_header "Get GuardDuty Finding Detail"

echo "Profile : ${PROFILE}"
echo "Region  : ${REGION}"

##########################################
# Caller Identity確認
#
# 想定したAWSアカウントで実行しているか確認する。
# GuardDuty Findingはアカウントとリージョンに紐づくため、
# 最初に実行主体を確認する。
##########################################

print_section "Caller Identity"

aws sts get-caller-identity \
  --profile "${PROFILE}" \
  --output table

##########################################
# GuardDuty Detector ID取得
#
# GuardDutyのFinding確認にはDetector IDが必要となる。
# Detectorが存在しない場合は、先に01_guardduty_enable.shを実行する。
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
# Finding ID取得
#
# list-findingsでFinding ID一覧を取得する。
# get-findingsで詳細を取得し、Severityの高いFindingを1件選ぶ。
#
# sort_byでSeverity順に並べ、[-1]で最大SeverityのFindingを選択する。
# Severityが同じFindingが複数ある場合は、その中の1件を扱う。
##########################################

print_section "Select High Severity Finding"

FINDING_IDS="$(aws guardduty list-findings \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --detector-id "${DETECTOR_ID}" \
  --max-results "${FINDING_SEARCH_LIMIT}" \
  --query 'FindingIds' \
  --output text)"

if [[ -z "${FINDING_IDS}" || "${FINDING_IDS}" == "None" ]]; then
  echo "No findings found."
  echo "Run 02_create_sample_findings.sh first."
  exit 1
fi

FINDING_ID="$(aws guardduty get-findings \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --detector-id "${DETECTOR_ID}" \
  --finding-ids ${FINDING_IDS} \
  --query 'sort_by(Findings, &Severity)[-1].Id' \
  --output text)"

if [[ -z "${FINDING_ID}" || "${FINDING_ID}" == "None" ]]; then
  echo "Could not select a finding."
  exit 1
fi

echo "Selected Finding ID: ${FINDING_ID}"

##########################################
# Finding基本情報
#
# まず見るべき基本情報を表示する。
# Severity、Type、Title、Descriptionで検知内容の全体像を把握する。
##########################################

print_section "Finding Basic Information"

aws guardduty get-findings \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --detector-id "${DETECTOR_ID}" \
  --finding-ids "${FINDING_ID}" \
  --query 'Findings[].{
    Severity:Severity,
    Type:Type,
    Title:Title,
    Description:Description,
    ResourceType:Resource.ResourceType,
    FirstSeen:Service.EventFirstSeen,
    LastSeen:Service.EventLastSeen
  }' \
  --output table

##########################################
# 対象リソース詳細
#
# Resourceには、検知対象となったAWSリソース情報が入る。
# EC2、IAM AccessKey、S3、RDS、Lambdaなど、Finding Typeにより中身が変わる。
##########################################

print_section "Finding Resource Detail"

aws guardduty get-findings \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --detector-id "${DETECTOR_ID}" \
  --finding-ids "${FINDING_ID}" \
  --query 'Findings[].Resource' \
  --output json

##########################################
# 検知アクション詳細
#
# Service.Actionには、GuardDutyが検知したアクション情報が入る。
# API Call、Network Connection、DNS Request、RDS Login Attemptなどを確認する。
##########################################

print_section "Finding Service Action"

aws guardduty get-findings \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --detector-id "${DETECTOR_ID}" \
  --finding-ids "${FINDING_ID}" \
  --query 'Findings[].Service.Action' \
  --output json

##########################################
# 調査観点
#
# Finding確認後に、実務で見るべきポイントを表示する。
# 実際の対応では、対象リソースとFinding Typeに応じて確認先を変える。
##########################################

print_section "Investigation Points"

cat <<EOF
General:
  - Severityを確認する
  - Typeを確認する
  - Title / Descriptionで検知内容を把握する
  - ResourceTypeと対象リソースIDを確認する
  - Service.Actionで検知された操作を確認する
  - FirstSeen / LastSeenで発生時間帯を確認する

IAM / AccessKey:
  - 対象IAMユーザーまたはRoleを確認する
  - Access Keyの利用状況を確認する
  - CloudTrailで該当時間帯のAPI操作を確認する
  - 不審なPolicy追加、Role作成、CloudTrail停止、S3操作がないか確認する
  - 必要に応じてAccess Key無効化、権限剥奪、認証情報ローテーションを行う

EC2 / Network:
  - 対象EC2のSecurity Groupを確認する
  - Public IP、Subnet、Route Tableを確認する
  - VPC Flow Logsで通信元、通信先、port、actionを確認する
  - 不審なOutbound通信やC2通信がないか確認する
  - 必要に応じてSecurity Group制限、Instance隔離、AMI取得、ログ保全を行う

S3:
  - 対象Bucket名を確認する
  - Block Public Accessを確認する
  - Bucket PolicyとACLを確認する
  - CloudTrail S3 Data Eventsで操作主体とAPIを確認する
  - 必要に応じてPublic Access遮断、Policy修正、Access Key無効化を行う

RDS:
  - 対象DB Instanceを確認する
  - 接続元IPとユーザーを確認する
  - Security GroupとSubnetを確認する
  - DBログ、CloudTrail、GuardDutyの時刻を突き合わせる
  - 必要に応じてパスワード変更、SG制限、認証情報ローテーションを行う

Lambda:
  - 対象Function名と実行Roleを確認する
  - VPC設定、Security Group、Subnetを確認する
  - CloudWatch Logsで実行ログを確認する
  - 外部通信先と実行Roleの権限を確認する
  - 必要に応じてRole権限修正、環境変数確認、関数停止を行う
EOF

##########################################
# 次の作業メモ
##########################################

print_header "GuardDuty finding detail completed"

cat <<EOF
Detector ID:
  ${DETECTOR_ID}

Selected Finding ID:
  ${FINDING_ID}

Next CLI checks:
  aws guardduty get-findings \\
    --profile ${PROFILE} \\
    --region ${REGION} \\
    --detector-id ${DETECTOR_ID} \\
    --finding-ids ${FINDING_ID} \\
    --output json

Next study:
  - Severityごとの優先度を整理する
  - Finding Typeごとの調査観点を整理する
  - IAM / S3 / EC2 / RDS / Lambdaの代表Findingを1つずつ読む
  - 実リソース構成とSecurity Group、Route Table、CloudTrail確認に進む

Notes:
  - High Severityは優先的に確認する。
  - Finding単体では断定せず、CloudTrailやVPC Flow Logsなどのログと突き合わせる。
  - 対応では、確認、封じ込め、原因調査、復旧、再発防止の順に整理する。
EOF

