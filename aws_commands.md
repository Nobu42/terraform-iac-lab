# AWS CLI コマンド集（LocalStack 確認用）

##  基本のルール
LocalStack を操作する際は、必ず末尾にエンドポイントを指定します。
- 例（外出先）： --endpoint-url http://localhost:4566
- 例（自宅Ubuntu）： --endpoint-url http://192.168.40.100:4566

> **Note:** 環境変数 AWS_ENDPOINT_URL を設定済みの場合は、URLの指定は不要です。

---

## 1. S3（ストレージ）の確認
'''bash
# バケットの一覧を表示
aws s3 ls

# 特定のバケット内のファイル一覧を表示
aws s3 ls s3://バケット名/

# ローカルファイルをバケットにアップロード
aws s3 cp test.txt s3://バケット名/
'''

---

## 2. EC2（仮想サーバー）の確認
'''bash
# インスタンスの一覧を表示
aws ec2 describe-instances

# 起動中のインスタンスのみ表示
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"

# セキュリティグループの一覧を表示
aws ec2 describe-security-groups
'''

---

## 3. IAM（権限・ユーザー）の確認
'''bash
# ユーザーの一覧を表示
aws iam list-users

# ロール（Role）の一覧を表示
aws iam list-roles
'''

---

## 4. 困った時の診断コマンド
'''bash
# LocalStack 自体のヘルスチェック
curl http://localhost:4566/_localstack/health

# 現在の自分の認証情報を表示
aws sts get-caller-identity
'''

---

## 5. ネットワーク（VPC周辺）の確認
'''bash
# VPCの一覧とCIDRを確認
aws ec2 describe-vpcs --query "Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State}" --output table

# サブネットがどのVPCに紐づいているか一覧表示
aws ec2 describe-subnets --query "Subnets[*].{ID:SubnetId,VPC:VpcId,AZ:AvailabilityZone,CIDR:CidrBlock}" --output table

# ルートテーブル（通信の経路図）の確認
aws ec2 describe-route-tables --query "RouteTables[*].{ID:RouteTableId,VPC:VpcId}" --output table

# インターネットゲートウェイ（外出口）の確認
aws ec2 describe-internet-gateways
'''

---

## 6. 運用・調査でよく使うコマンド
'''bash
# インスタンスの「パブリックIP」だけを取得
aws ec2 describe-instances --query "Reservations[*].Instances[*].PublicIpAddress" --output text

# セキュリティグループの「許可ルール」を詳しく見る
aws ec2 describe-security-groups --group-ids グループID

# SSM経由でログイン（実務の主流）
aws ssm start-session --target インスタンスID
'''

---

## 7. クォータ（制限）とリージョンの確認
'''bash
# 使用可能なアベイラビリティゾーン(AZ)を確認
aws ec2 describe-availability-zones --query "AvailabilityZones[*].ZoneName" --output text

# 自分のアカウントで使えるリージョンの一覧
aws ec2 describe-regions --output table
'''
