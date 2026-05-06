#!/bin/bash

set -euo pipefail

# ================================================================
# Create CloudWatch Alarms
#
# このスクリプトは、日次ラボ環境で作成したAWSリソースに対して、
# CloudWatch Alarmを作成するためのスクリプト。
#
# 目的:
#   - Webアプリケーション基盤の運用監視で、最低限見るべき項目を
#     CloudWatch Alarmとして定義する。
#   - EC2 / ALB / RDS / ElastiCache の異常を検知できるようにする。
#   - Terraform化する前に、AWS CLIで監視項目とメトリクス名を理解する。
#
# 作成するAlarm:
#   EC2:
#     - CPUUtilization
#       Web EC2のCPU使用率が高い状態を検知する。
#
#     - StatusCheckFailed
#       EC2インスタンスまたはAWS基盤側のステータスチェック失敗を検知する。
#
#   ALB:
#     - HTTPCode_ELB_5XX_Count
#       ALB自身が返した5xxエラーを検知する。
#
#     - HealthyHostCount
#       Target Group配下の正常なWeb EC2台数が不足したことを検知する。
#
#   RDS:
#     - CPUUtilization
#       RDSのCPU使用率が高い状態を検知する。
#
#     - FreeStorageSpace
#       RDSの空きストレージ容量が少ない状態を検知する。
#
#     - DatabaseConnections
#       RDSへの接続数が多い状態を検知する。
#
#   ElastiCache:
#     - CPUUtilization
#       RedisノードのCPU使用率が高い状態を検知する。
#
#     - CurrConnections
#       Redisへの接続数が多い状態を検知する。
#
# 注意:
#   - このスクリプトではSNS通知先を設定しない。
#   - まずはCloudWatch Alarmの作成と状態確認を目的とするため、
#     --no-actions-enabled を指定している。
#   - Alarm状態がALARMになってもメール通知などは送信されない。
#   - 後続でSNS Topic / Email通知 / Chatbot連携を追加する。
#
# 前提:
#   - 01-aws-cli/scripts/All_Setup.sh により、AWSリソースが作成済みであること。
#   - Web EC2が sample-ec2-web01 / sample-ec2-web02 というNameタグで起動していること。
#   - ALB名が sample-elb であること。
#   - Target Group名が sample-tg であること。
#   - RDS DB Instance Identifier が sample-db であること。
#   - ElastiCache Replication Group ID が sample-elasticache であること。
#
# 実行例:
#   cd /Users/nobu/terraform-iac-lab/03-cloudwatch/scripts
#   chmod +x 01_create_alarms.sh
#   ./01_create_alarms.sh
#
# 確認例:
#   aws cloudwatch describe-alarms \
#     --profile learning \
#     --region ap-northeast-1 \
#     --alarm-name-prefix nobu-iac-lab \
#     --output table
# ================================================================

PROFILE="learning"
REGION="ap-northeast-1"

PROJECT_NAME="nobu-iac-lab"

ALB_NAME="sample-elb"
TARGET_GROUP_NAME="sample-tg"
RDS_INSTANCE_ID="sample-db"
ELASTICACHE_REPLICATION_GROUP_ID="sample-elasticache"

# EC2 CPU使用率のしきい値。
# 学習環境では通常ほとんどCPUを使わないため、80%を超えたら異常候補として扱う。
EC2_CPU_THRESHOLD="80"

# RDS CPU使用率のしきい値。
# 小規模な学習用DBで80%が続く場合は、重いクエリや接続集中を疑う。
RDS_CPU_THRESHOLD="80"

# RDS空きストレージ容量のしきい値。
# CloudWatchの FreeStorageSpace は Bytes 単位。
# ここでは 5GiB = 5 * 1024 * 1024 * 1024 = 5368709120 bytes を下回ったら検知する。
RDS_FREE_STORAGE_THRESHOLD_BYTES="5368709120"

# RDS接続数のしきい値。
# 実務ではDBインスタンスサイズやアプリの接続プール設定に合わせて調整する。
# このラボでは目安として80接続以上を高い状態として扱う。
RDS_CONNECTIONS_THRESHOLD="80"

# ElastiCache CPU使用率のしきい値。
# RedisのCPU使用率が高い場合、アクセス集中や重い操作を疑う。
ELASTICACHE_CPU_THRESHOLD="80"

# ElastiCache接続数のしきい値。
# 学習環境では接続数は少ない想定なので、100以上を高い状態として扱う。
ELASTICACHE_CONNECTIONS_THRESHOLD="100"

echo "================================================"
echo "Create CloudWatch Alarms"
echo "================================================"

echo "=== Caller Identity ==="
# 実行前にAWSアカウントを確認する。
# 誤ったprofileやアカウントでAlarmを作成しないための安全確認。
aws sts get-caller-identity \
  --profile "${PROFILE}" \
  --output table

echo "=== Get EC2 instance IDs ==="
# Web EC2のInstanceIdをNameタグから取得する。
# 日次ラボではEC2を毎回作り直すため、InstanceIdは毎回変わる。
# そのため、固定のInstanceIdをスクリプトに書かず、タグから動的に取得する。
WEB_INSTANCE_IDS=$(aws ec2 describe-instances \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --filters \
    "Name=tag:Name,Values=sample-ec2-web01,sample-ec2-web02" \
    "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

# InstanceIdが取得できない場合は、後続のAlarm作成ができないため中断する。
# All_Setup.shが未実行、またはWeb EC2が起動していない可能性がある。
if [ -z "${WEB_INSTANCE_IDS}" ] || [ "${WEB_INSTANCE_IDS}" = "None" ]; then
  echo "ERROR: Running web EC2 instances were not found."
  echo "Please run All_Setup.sh first and check EC2 Name tags."
  exit 1
fi

echo "Web Instances:"
echo "  ${WEB_INSTANCE_IDS}"

echo "=== Create EC2 alarms ==="
for INSTANCE_ID in ${WEB_INSTANCE_IDS}; do
  echo "Creating EC2 CPU alarm for ${INSTANCE_ID}"

  # EC2 CPUUtilization Alarm
  #
  # namespace:
  #   EC2メトリクスは AWS/EC2 名前空間に保存される。
  #
  # dimensions:
  #   EC2のメトリクスは InstanceId を指定して対象インスタンスを絞り込む。
  #
  # statistic:
  #   Averageを使い、5分間の平均CPU使用率を見る。
  #
  # period:
  #   300秒 = 5分。
  #
  # evaluation-periods:
  #   2回連続でしきい値を超えたらALARMにする。
  #   つまり、約10分間CPUが高い状態が続いた場合に検知する。
  #
  # treat-missing-data:
  #   データ欠損時は異常扱いにしない。
  #   EC2停止中や作成直後のメトリクス未送信で不要なALARMにしないため。
  aws cloudwatch put-metric-alarm \
    --profile "${PROFILE}" \
    --region "${REGION}" \
    --alarm-name "${PROJECT_NAME}-ec2-${INSTANCE_ID}-cpu-high" \
    --alarm-description "EC2 CPUUtilization is high on ${INSTANCE_ID}" \
    --namespace "AWS/EC2" \
    --metric-name "CPUUtilization" \
    --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" \
    --statistic "Average" \
    --period 300 \
    --evaluation-periods 2 \
    --threshold "${EC2_CPU_THRESHOLD}" \
    --comparison-operator "GreaterThanOrEqualToThreshold" \
    --treat-missing-data "notBreaching" \
    --no-actions-enabled

  echo "Creating EC2 status check alarm for ${INSTANCE_ID}"

  # EC2 StatusCheckFailed Alarm
  #
  # StatusCheckFailed は、以下のどちらかの異常で 1 になる。
  #   - インスタンス側の問題
  #   - AWS基盤側の問題
  #
  # statistic:
  #   Maximumを使う。
  #   1分間の中で一度でも失敗があれば検知しやすくするため。
  #
  # period:
  #   60秒。
  #
  # evaluation-periods:
  #   2回連続で失敗したらALARMにする。
  #   一瞬の揺らぎではなく、継続した異常を検知する。
  aws cloudwatch put-metric-alarm \
    --profile "${PROFILE}" \
    --region "${REGION}" \
    --alarm-name "${PROJECT_NAME}-ec2-${INSTANCE_ID}-status-check-failed" \
    --alarm-description "EC2 StatusCheckFailed is detected on ${INSTANCE_ID}" \
    --namespace "AWS/EC2" \
    --metric-name "StatusCheckFailed" \
    --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" \
    --statistic "Maximum" \
    --period 60 \
    --evaluation-periods 2 \
    --threshold 1 \
    --comparison-operator "GreaterThanOrEqualToThreshold" \
    --treat-missing-data "notBreaching" \
    --no-actions-enabled
done

echo "=== Get ALB and Target Group dimensions ==="
# ALB系メトリクスでは、CloudWatch DimensionにARN全体ではなく、
# ARNの一部を使う必要がある。
#
# LoadBalancer dimension:
#   app/sample-elb/xxxxxxxxxxxxxxxx
#
# TargetGroup dimension:
#   targetgroup/sample-tg/yyyyyyyyyyyyyyyy
#
# そのため、describe-load-balancers / describe-target-groups でARNを取得し、
# bashの文字列処理でCloudWatch用のDimension値へ変換する。

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

# ARNから "loadbalancer/" より後ろを取り出す。
# 例:
#   arn:aws:elasticloadbalancing:...:loadbalancer/app/sample-elb/abc
#   -> app/sample-elb/abc
ALB_DIMENSION="${ALB_ARN#*loadbalancer/}"

# ARNから "targetgroup/" より後ろを取り出し、
# CloudWatch Dimension形式に合わせて先頭に "targetgroup/" を戻す。
# 例:
#   arn:aws:elasticloadbalancing:...:targetgroup/sample-tg/def
#   -> targetgroup/sample-tg/def
TARGET_GROUP_DIMENSION="${TARGET_GROUP_ARN#*targetgroup/}"
TARGET_GROUP_DIMENSION="targetgroup/${TARGET_GROUP_DIMENSION}"

echo "ALB Dimension          : ${ALB_DIMENSION}"
echo "Target Group Dimension : ${TARGET_GROUP_DIMENSION}"

echo "=== Create ALB alarms ==="

# ALB 5xx Alarm
#
# HTTPCode_ELB_5XX_Count は、ALB自身が返した5xxエラー数。
# アプリケーションが返した5xxは HTTPCode_Target_5XX_Count になるため別物。
#
# 今回はまずALB自身の異常を検知する。
# 例:
#   - ALB設定不備
#   - Targetへ転送できない
#   - ALB側でエラー応答が発生している
#
# statistic:
#   Sumを使い、5分間に発生した5xx件数を見る。
#
# threshold:
#   1以上。
#   学習環境では5xxが1件でも出たら確認対象にする。
aws cloudwatch put-metric-alarm \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --alarm-name "${PROJECT_NAME}-alb-5xx-high" \
  --alarm-description "ALB 5xx errors are detected" \
  --namespace "AWS/ApplicationELB" \
  --metric-name "HTTPCode_ELB_5XX_Count" \
  --dimensions "Name=LoadBalancer,Value=${ALB_DIMENSION}" \
  --statistic "Sum" \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --treat-missing-data "notBreaching" \
  --no-actions-enabled

# Target Group HealthyHostCount Alarm
#
# HealthyHostCount は、Target Group内で正常判定されているターゲット数。
# このラボでは web01 / web02 の2台構成を想定している。
#
# threshold:
#   2未満ならALARM。
#   つまり、正常なWeb EC2が1台以下になった場合に検知する。
#
# treat-missing-data:
#   breaching にしている。
#   メトリクスが取れない状態も、ALB/Target Group周辺の異常として扱うため。
aws cloudwatch put-metric-alarm \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --alarm-name "${PROJECT_NAME}-targetgroup-healthy-host-low" \
  --alarm-description "HealthyHostCount is less than expected" \
  --namespace "AWS/ApplicationELB" \
  --metric-name "HealthyHostCount" \
  --dimensions \
    "Name=TargetGroup,Value=${TARGET_GROUP_DIMENSION}" \
    "Name=LoadBalancer,Value=${ALB_DIMENSION}" \
  --statistic "Minimum" \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 2 \
  --comparison-operator "LessThanThreshold" \
  --treat-missing-data "breaching" \
  --no-actions-enabled

echo "=== Create RDS alarms ==="

# RDS CPUUtilization Alarm
#
# RDSのCPU使用率を監視する。
# CPUが高い状態が続く場合、以下を確認する。
#   - アプリケーションからのアクセス集中
#   - 重いSQL
#   - インデックス不足
#   - DBインスタンスサイズ不足
aws cloudwatch put-metric-alarm \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --alarm-name "${PROJECT_NAME}-rds-cpu-high" \
  --alarm-description "RDS CPUUtilization is high" \
  --namespace "AWS/RDS" \
  --metric-name "CPUUtilization" \
  --dimensions "Name=DBInstanceIdentifier,Value=${RDS_INSTANCE_ID}" \
  --statistic "Average" \
  --period 300 \
  --evaluation-periods 2 \
  --threshold "${RDS_CPU_THRESHOLD}" \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --treat-missing-data "notBreaching" \
  --no-actions-enabled

# RDS FreeStorageSpace Alarm
#
# RDSの空きストレージ容量を監視する。
# FreeStorageSpace はBytes単位で返る。
#
# 空き容量が少なくなると、DB書き込み失敗や停止につながる可能性がある。
# 学習環境でも、RDS監視項目として重要。
aws cloudwatch put-metric-alarm \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --alarm-name "${PROJECT_NAME}-rds-free-storage-low" \
  --alarm-description "RDS FreeStorageSpace is low" \
  --namespace "AWS/RDS" \
  --metric-name "FreeStorageSpace" \
  --dimensions "Name=DBInstanceIdentifier,Value=${RDS_INSTANCE_ID}" \
  --statistic "Average" \
  --period 300 \
  --evaluation-periods 2 \
  --threshold "${RDS_FREE_STORAGE_THRESHOLD_BYTES}" \
  --comparison-operator "LessThanThreshold" \
  --treat-missing-data "notBreaching" \
  --no-actions-enabled

# RDS DatabaseConnections Alarm
#
# RDSへの接続数を監視する。
# Railsアプリでは、Puma worker/thread数やDB connection poolの設定によって
# 接続数が増えることがある。
#
# 2台のWeb EC2から同じRDSへ接続する構成では、
# Web台数が増えるほどDB接続数も増えるため、運用監視の観点で重要。
aws cloudwatch put-metric-alarm \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --alarm-name "${PROJECT_NAME}-rds-database-connections-high" \
  --alarm-description "RDS DatabaseConnections is high" \
  --namespace "AWS/RDS" \
  --metric-name "DatabaseConnections" \
  --dimensions "Name=DBInstanceIdentifier,Value=${RDS_INSTANCE_ID}" \
  --statistic "Average" \
  --period 300 \
  --evaluation-periods 2 \
  --threshold "${RDS_CONNECTIONS_THRESHOLD}" \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --treat-missing-data "notBreaching" \
  --no-actions-enabled

echo "=== Create ElastiCache alarms ==="

# ElastiCache CPUUtilization Alarm
#
# RedisノードのCPU使用率を監視する。
# CPUが高い場合、アクセス集中や重いRedis操作を疑う。
#
# RedisはメモリだけでなくCPUもボトルネックになるため、
# ElastiCacheの基本監視項目として追加している。
aws cloudwatch put-metric-alarm \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --alarm-name "${PROJECT_NAME}-elasticache-cpu-high" \
  --alarm-description "ElastiCache CPUUtilization is high" \
  --namespace "AWS/ElastiCache" \
  --metric-name "CPUUtilization" \
  --dimensions "Name=ReplicationGroupId,Value=${ELASTICACHE_REPLICATION_GROUP_ID}" \
  --statistic "Average" \
  --period 300 \
  --evaluation-periods 2 \
  --threshold "${ELASTICACHE_CPU_THRESHOLD}" \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --treat-missing-data "notBreaching" \
  --no-actions-enabled

# ElastiCache CurrConnections Alarm
#
# CurrConnections はRedisへの現在の接続数。
# Railsアプリからキャッシュやセッション用途でRedisを使う場合、
# Web台数やPuma thread数に応じて接続数が増える。
#
# 接続数が想定より多い場合は、アプリ側の接続管理や
# ElastiCacheノードサイズを確認する。
aws cloudwatch put-metric-alarm \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --alarm-name "${PROJECT_NAME}-elasticache-curr-connections-high" \
  --alarm-description "ElastiCache CurrConnections is high" \
  --namespace "AWS/ElastiCache" \
  --metric-name "CurrConnections" \
  --dimensions "Name=ReplicationGroupId,Value=${ELASTICACHE_REPLICATION_GROUP_ID}" \
  --statistic "Average" \
  --period 300 \
  --evaluation-periods 2 \
  --threshold "${ELASTICACHE_CONNECTIONS_THRESHOLD}" \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --treat-missing-data "notBreaching" \
  --no-actions-enabled

echo "=== Show created alarms ==="
# 作成したAlarmを一覧表示する。
# StateValueは作成直後だと INSUFFICIENT_DATA になることがある。
# メトリクスが数分蓄積されると OK または ALARM に変化する。
aws cloudwatch describe-alarms \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --alarm-name-prefix "${PROJECT_NAME}" \
  --query "MetricAlarms[].{AlarmName:AlarmName,StateValue:StateValue,MetricName:MetricName,Namespace:Namespace}" \
  --output table

echo "================================================"
echo "CloudWatch Alarm creation completed."
echo
echo "Next checks:"
echo "  aws cloudwatch describe-alarms \\"
echo "    --profile ${PROFILE} \\"
echo "    --region ${REGION} \\"
echo "    --alarm-name-prefix ${PROJECT_NAME} \\"
echo "    --output table"
echo
echo "Notes:"
echo "  - Alarm actions are disabled in this version."
echo "  - Created alarms may initially show INSUFFICIENT_DATA."
echo "  - Add SNS notification after the basic alarm behavior is confirmed."
echo "================================================"

