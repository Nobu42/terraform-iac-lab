#!/usr/bin/env bash
set -euo pipefail

##########################################
# GuardDuty Enable Script
#
# 目的:
#   Amazon GuardDutyを東京リージョンで有効化する。
#
# このスクリプトで行うこと:
#   1. AWS CLIの実行アカウントを確認する
#   2. GuardDuty Detectorの有無を確認する
#   3. Detectorがなければ作成する
#   4. Detector IDを表示する
#   5. 次に実行する確認コマンドを表示する
#
# 注意:
#   GuardDutyは有効化中に課金対象となる。
#   学習後に不要ならdelete-detectorで削除する。
##########################################

##########################################
# 基本設定
##########################################

# AWS CLIで使用するプロファイル
PROFILE="learning"

# GuardDutyを有効化するリージョン
REGION="ap-northeast-1"

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

print_header "Enable Amazon GuardDuty"

echo "Profile : ${PROFILE}"
echo "Region  : ${REGION}"

##########################################
# Caller Identity確認
# 想定したAWSアカウントで実行しているかを最初に確認する。
# GuardDutyはアカウント単位・リージョン単位で有効化されるため、
# 誤ったprofileやregionで実行しないことが重要となる。
##########################################

print_section "Caller Identity"

aws sts get-caller-identity \
  --profile "${PROFILE}" \
  --output table

##########################################
# GuardDuty Detector確認
#
# GuardDutyでは、有効化された単位をDetectorと呼ぶ。
# Detectorはリージョン単位で作成される。
#
# list-detectorsの結果が空なら、対象リージョンでは
# GuardDutyがまだ有効化されていない状態となる。
##########################################

print_section "Check GuardDuty Detector"

DETECTOR_ID="$(aws guardduty list-detectors \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --query 'DetectorIds[0]' \
  --output text)"

##########################################
# Detector作成
#
# list-detectorsの戻り値がNoneの場合、Detectorが存在しない。
# create-detector --enable により GuardDutyを有効化する。
#
# すでにDetectorが存在する場合は、新規作成せず既存IDを使う。
# これにより、同じスクリプトを再実行しても重複作成しない。
##########################################

if [[ "${DETECTOR_ID}" == "None" || -z "${DETECTOR_ID}" ]]; then
  print_section "Create GuardDuty Detector"

  DETECTOR_ID="$(aws guardduty create-detector \
    --profile "${PROFILE}" \
    --region "${REGION}" \
    --enable \
    --query 'DetectorId' \
    --output text)"

  echo "Created Detector ID: ${DETECTOR_ID}"
else
  echo "GuardDuty Detector already exists."
  echo "Detector ID: ${DETECTOR_ID}"
fi

##########################################
# Detector状態確認
#
# get-detectorで現在のGuardDuty設定を確認する。
# ServiceRole, Status, FindingPublishingFrequencyなどを確認できる。
##########################################

print_section "Show GuardDuty Detector"

aws guardduty get-detector \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --detector-id "${DETECTOR_ID}" \
  --output table

##########################################
# 次の作業メモ
##########################################

print_header "GuardDuty enable completed"

cat <<EOF
Detector ID:
  ${DETECTOR_ID}

Next checks:
  aws guardduty list-detectors \\
    --profile ${PROFILE} \\
    --region ${REGION}

  aws guardduty get-detector \\
    --profile ${PROFILE} \\
    --region ${REGION} \\
    --detector-id ${DETECTOR_ID} \\
    --output table

Next step:
  - サンプルFindingを生成する
  - 学習後に不要ならGuardDutyを削除する

Cleanup command:
  aws guardduty delete-detector \\
    --profile ${PROFILE} \\
    --region ${REGION} \\
    --detector-id ${DETECTOR_ID}

Notes:
  - GuardDutyはリージョン単位で有効化される。
  - 有効化中は課金対象となる。
  - サンプルFinding生成は次のスクリプトで扱う
EOF
