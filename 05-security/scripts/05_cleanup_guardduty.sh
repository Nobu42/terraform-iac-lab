#!/usr/bin/env bash
set -euo pipefail

##########################################
# GuardDuty Cleanup Script
#
# 目的:
#   東京リージョンで有効化したGuardDuty Detectorを削除する。
#
# このスクリプトで行うこと:
#   1. AWS CLIの実行アカウントを確認する
#   2. GuardDuty Detector IDを取得する
#   3. Finding件数を確認する
#   4. 削除前に確認入力を求める
#   5. GuardDuty Detectorを削除する
#   6. 削除後にDetectorが残っていないことを確認する
#
# 注意:
#   Detectorを削除すると、GuardDutyのFindingも確認できなくなる。
#   明日もFindingを見返す場合は、このスクリプトをまだ実行しない。
#   GuardDutyは有効化中に課金対象となる。
##########################################

##########################################
# 基本設定
##########################################

# AWS CLIで使用するプロファイル
PROFILE="learning"

# GuardDutyを削除するリージョン
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

print_header "Cleanup Amazon GuardDuty"

echo "Profile : ${PROFILE}"
echo "Region  : ${REGION}"

##########################################
# Caller Identity確認
#
# 削除操作のため、想定したAWSアカウントで実行しているか確認する。
# 誤ったprofileで実行しないことが重要となる。
##########################################

print_section "Caller Identity"

aws sts get-caller-identity \
  --profile "${PROFILE}" \
  --output table

##########################################
# GuardDuty Detector ID取得
#
# GuardDuty Detectorはリージョン単位で存在する。
# 対象リージョンにDetectorが存在しない場合は、削除対象なしとして終了する。
##########################################

print_section "Get GuardDuty Detector ID"

DETECTOR_ID="$(aws guardduty list-detectors \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --query 'DetectorIds[0]' \
  --output text)"

if [[ "${DETECTOR_ID}" == "None" || -z "${DETECTOR_ID}" ]]; then
  echo "GuardDuty Detector is not found."
  echo "Nothing to cleanup."
  exit 0
fi

echo "Detector ID: ${DETECTOR_ID}"

##########################################
# Detector状態確認
#
# 削除前にDetectorの状態を確認する。
# StatusがENABLEDの場合、GuardDutyが有効化されている。
##########################################

print_section "Show GuardDuty Detector"

aws guardduty get-detector \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --detector-id "${DETECTOR_ID}" \
  --output table

##########################################
# Finding件数確認
#
# 削除前にFinding ID一覧を取得し、件数を表示する。
# Detector削除後はFindingを確認できなくなるため、
# 必要なら先にメモやJSON出力を保存する。
##########################################

print_section "Check Finding Count"

FINDING_COUNT="$(aws guardduty list-findings \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --detector-id "${DETECTOR_ID}" \
  --query 'length(FindingIds)' \
  --output text)"

echo "Finding count: ${FINDING_COUNT}"

##########################################
# 削除確認
#
# 誤削除を避けるため、明示的にyesを入力した場合のみ削除する。
##########################################

print_section "Confirm Cleanup"

cat <<EOF
This operation deletes GuardDuty Detector.

Detector ID:
  ${DETECTOR_ID}

Region:
  ${REGION}

Finding count:
  ${FINDING_COUNT}

After deletion:
  - GuardDuty is disabled in this region.
  - Existing findings are no longer available.
  - To continue study tomorrow, do not run cleanup now.

Type 'yes' to delete GuardDuty Detector.
EOF

read -r -p "Enter value: " CONFIRM

if [[ "${CONFIRM}" != "yes" ]]; then
  echo "Cleanup canceled."
  exit 0
fi

##########################################
# GuardDuty Detector削除
#
# delete-detectorにより、対象リージョンのGuardDutyを削除する。
##########################################

print_section "Delete GuardDuty Detector"

aws guardduty delete-detector \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --detector-id "${DETECTOR_ID}"

echo "GuardDuty Detector deleted."

##########################################
# 削除後確認
#
# list-detectorsでDetectorが残っていないことを確認する。
##########################################

print_section "Verify GuardDuty Detector"

REMAINING_DETECTOR_ID="$(aws guardduty list-detectors \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --query 'DetectorIds[0]' \
  --output text)"

if [[ "${REMAINING_DETECTOR_ID}" == "None" || -z "${REMAINING_DETECTOR_ID}" ]]; then
  echo "GuardDuty Detector is not found."
  echo "Cleanup verified."
else
  echo "GuardDuty Detector still exists."
  echo "Remaining Detector ID: ${REMAINING_DETECTOR_ID}"
  exit 1
fi

##########################################
# 完了メッセージ
##########################################

print_header "GuardDuty cleanup completed"

cat <<EOF
Deleted Detector ID:
  ${DETECTOR_ID}

Region:
  ${REGION}

Next checks:
  aws guardduty list-detectors \\
    --profile ${PROFILE} \\
    --region ${REGION}

Notes:
  - GuardDuty Detectorを削除した。
  - 既存Findingは確認できなくなる。
  - 再度学習する場合は01_guardduty_enable.shから実行する。
EOF

