#!/usr/bin/env bash
set -euo pipefail

##########################################
# GuardDuty Findings By Resource Type Script
#
# 目的:
#   GuardDuty FindingをResourceTypeで絞り込み、調査対象に近いFindingだけを確認する。
#
# このスクリプトで行うこと:
#   1. AWS CLIの実行アカウントを確認する
#   2. GuardDuty Detector IDを取得する
#   3. Finding一覧を取得する
#   4. ResourceTypeでFindingを絞り込む
#   5. Severity、Type、Title、ResourceTypeを一覧表示する
#   6. 対象Findingの詳細確認コマンドを表示する
#
# 使い方:
#   ./04_get_findings_by_type.sh
#   ./04_get_findings_by_type.sh S3Bucket
#   ./04_get_findings_by_type.sh AccessKey
#   ./04_get_findings_by_type.sh Instance
#   ./04_get_findings_by_type.sh RDSDBInstance
#   ./04_get_findings_by_type.sh Lambda
#
# 注意:
#   サンプルFindingは実際の攻撃や侵害ではない。
#   実務ではResourceTypeだけで判断せず、Type、Severity、対象リソース、ログを突き合わせる。
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

# 絞り込み対象のResourceType
# 引数がない場合はS3Bucketを初期値とする。
TARGET_RESOURCE_TYPE="${1:-S3Bucket}"

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

print_header "Get GuardDuty Findings By Resource Type"

echo "Profile              : ${PROFILE}"
echo "Region               : ${REGION}"
echo "Target Resource Type : ${TARGET_RESOURCE_TYPE}"

##########################################
# Caller Identity確認
#
# 想定したAWSアカウントで実行しているか確認する。
# GuardDuty Findingはアカウントとリージョンに紐づく。
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
# Finding ID一覧取得
#
# list-findingsでFinding ID一覧を取得する。
# 詳細情報はget-findingsで取得する。
##########################################

print_section "List Finding IDs"

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

echo "${FINDING_IDS}" | tr '\t' '\n'

##########################################
# ResourceTypeでFindingを絞り込み
#
# get-findingsで取得したFindingのうち、
# Resource.ResourceTypeがTARGET_RESOURCE_TYPEと一致するものだけを表示する。
#
# containsではなく完全一致で絞るため、
# S3Bucket、AccessKey、Instance、RDSDBInstance、Lambdaなどを指定する。
##########################################

print_section "Filtered Finding Summary"

aws guardduty get-findings \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --detector-id "${DETECTOR_ID}" \
  --finding-ids ${FINDING_IDS} \
  --query "Findings[?Resource.ResourceType=='${TARGET_RESOURCE_TYPE}'].{Id:Id,Severity:Severity,Type:Type,Title:Title,ResourceType:Resource.ResourceType}" \
  --output table

##########################################
# 対象Finding ID抽出
#
# 後続の詳細確認に使うため、ResourceTypeが一致したFinding IDだけを取得する。
##########################################

print_section "Filtered Finding IDs"

FILTERED_FINDING_IDS="$(aws guardduty get-findings \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --detector-id "${DETECTOR_ID}" \
  --finding-ids ${FINDING_IDS} \
  --query "Findings[?Resource.ResourceType=='${TARGET_RESOURCE_TYPE}'].Id" \
  --output text)"

if [[ -z "${FILTERED_FINDING_IDS}" || "${FILTERED_FINDING_IDS}" == "None" ]]; then
  echo "No findings matched ResourceType: ${TARGET_RESOURCE_TYPE}"
  echo
  echo "Try another ResourceType:"
  echo "  S3Bucket"
  echo "  AccessKey"
  echo "  Instance"
  echo "  RDSDBInstance"
  echo "  Lambda"
  echo "  AttackSequence"
  echo "  EKSCluster"
  exit 0
fi

echo "${FILTERED_FINDING_IDS}" | tr '\t' '\n'

##########################################
# 調査観点
#
# ResourceTypeごとに最初に見るポイントを表示する。
##########################################

print_section "Investigation Points"

case "${TARGET_RESOURCE_TYPE}" in
  "S3Bucket")
    cat <<EOF
S3Bucket:
  - 対象Bucket名を確認する
  - Block Public Accessを確認する
  - Bucket PolicyとACLを確認する
  - 暗号化とVersioningを確認する
  - CloudTrail S3 Data Eventsで操作主体、API、接続元を確認する
  - IAM User / Role / Access Keyの権限を確認する
EOF
    ;;
  "AccessKey")
    cat <<EOF
AccessKey:
  - 対象Access Key IDを確認する
  - 対象IAMユーザーまたはRoleを確認する
  - CloudTrailで該当時間帯のAPI操作を確認する
  - 不審なAPI、接続元IP、リージョン、UserAgentを確認する
  - 必要に応じてAccess Key無効化、権限剥奪、認証情報ローテーションを行う
EOF
    ;;
  "Instance")
    cat <<EOF
Instance:
  - 対象EC2 Instance IDを確認する
  - Security Group、Subnet、Route Tableを確認する
  - Public IPと外部公開状態を確認する
  - VPC Flow Logsで通信元、通信先、port、actionを確認する
  - CloudWatch Logs、OSログ、プロセス、cronを確認する
  - 必要に応じてInstance隔離、SG制限、AMI取得、ログ保全を行う
EOF
    ;;
  "RDSDBInstance")
    cat <<EOF
RDSDBInstance:
  - 対象DB Instance Identifierを確認する
  - 接続元IP、DBユーザー、認証方式を確認する
  - Security GroupとSubnet Groupを確認する
  - RDSログとCloudTrailを確認する
  - 不審なログイン成功、失敗、時間帯、接続元を確認する
  - 必要に応じてパスワード変更、SG制限、認証情報ローテーションを行う
EOF
    ;;
  "Lambda")
    cat <<EOF
Lambda:
  - 対象Function名とFunction ARNを確認する
  - 実行Roleの権限を確認する
  - VPC設定、Security Group、Subnetを確認する
  - CloudWatch Logsで実行ログを確認する
  - 外部通信先、環境変数、Layer、デプロイ履歴を確認する
  - 必要に応じて関数停止、Role権限修正、環境変数ローテーションを行う
EOF
    ;;
  *)
    cat <<EOF
General:
  - Severityを確認する
  - Typeを確認する
  - Title / Descriptionを確認する
  - ResourceTypeと対象リソースを確認する
  - Service.Actionを確認する
  - CloudTrail、VPC Flow Logs、CloudWatch Logsなど関連ログを確認する
EOF
    ;;
esac

##########################################
# 次の作業メモ
##########################################

print_header "GuardDuty findings by resource type completed"

cat <<EOF
Detector ID:
  ${DETECTOR_ID}

Target ResourceType:
  ${TARGET_RESOURCE_TYPE}

Matched Finding IDs:
$(echo "${FILTERED_FINDING_IDS}" | tr '\t' '\n' | sed 's/^/  /')

Next CLI check:
  aws guardduty get-findings \\
    --profile ${PROFILE} \\
    --region ${REGION} \\
    --detector-id ${DETECTOR_ID} \\
    --finding-ids ${FILTERED_FINDING_IDS} \\
    --output json

Examples:
  ./04_get_findings_by_type.sh S3Bucket
  ./04_get_findings_by_type.sh AccessKey
  ./04_get_findings_by_type.sh Instance
  ./04_get_findings_by_type.sh RDSDBInstance
  ./04_get_findings_by_type.sh Lambda

Notes:
  - ResourceTypeで絞ると、自分の調査対象に近いFindingを読みやすくなる。
  - 実務ではFindingの内容だけでなく、CloudTrailやVPC Flow Logsなどの証跡と突き合わせる。
  - 設定変更前には、影響範囲、作業手順、正常性確認、切り戻し手順を整理する。
EOF

