# [10] Database (RDS) 構築演習

## 1. 概要
Amazon RDS (MySQL 8.0) を構築するための各種グループ設定およびインスタンスの作成を行う。
高可用性とマルチAZ構成を見据えた「DBサブネットグループ」の作成を含む。

## 2. 設計詳細

### A. パラメータグループ (DB Parameter Group)
DBエンジンの動作（タイムゾーンや文字コード等）を制御する設定群。
| 項目 | 設定値 |
| :--- | :--- |
| パラメータグループファミリー | mysql8.0 |
| グループ名 | sample-db-pg |
| 説明 | sample parameter group |

### B. オプショングループ (DB Option Group)
追加機能（プラグイン等）を有効化するための設定群。
| 項目 | 設定値 |
| :--- | :--- |
| エンジン | mysql |
| メジャーバージョン | 8.0 |
| グループ名 | sample-db-og |
| 説明 | sample option group |

### C. DBサブネットグループ (DB Subnet Group)
RDS インスタンスを配置するプライベートサブネットの定義。
| 項目 | 設定値 |
| :--- | :--- |
| グループ名 | sample-db-subnet |
| 説明 | sample db subnet |
| VPC | sample-vpc |
| 配置AZ | ap-northeast-1a, ap-northeast-1c |
| 使用サブネット | sample-subnet-private01, sample-subnet-private02 |

---

## 3. 構築コマンド (AWS CLI / LocalStack)

### 3.1 DBパラメータグループの作成
```bash
aws --endpoint-url=http://localhost:4566 rds create-db-parameter-group \
    --db-parameter-group-name sample-db-pg \
    --db-parameter-group-family mysql8.0 \
    --description "sample parameter group"
```
### 3.2 DBオプショングループの作成
```bash
aws --endpoint-url=http://localhost:4566 rds create-db-option-group \
    --db-option-group-name sample-db-og \
    --engine-name mysql \
    --major-engine-version 8.0 \
    --option-group-description "sample option group"
```

### 3.3 DBサブネットグループの作成
```bash
# サブネットIDの取得
SUBNET_PRIV01=$(aws --endpoint-url=http://localhost:4566 ec2 describe-subnets --filters "Name=tag:Name,Values=sample-subnet-private01" --query "Subnets[0].SubnetId" --output text)
SUBNET_PRIV02=$(aws --endpoint-url=http://localhost:4566 ec2 describe-subnets --filters "Name=tag:Name,Values=sample-subnet-private02" --query "Subnets[0].SubnetId" --output text)

# サブネットグループの作成
aws --endpoint-url=http://localhost:4566 rds create-db-subnet-group \
    --db-subnet-group-name sample-db-subnet \
    --db-subnet-group-description "sample db subnet" \
    --subnet-ids "$SUBNET_PRIV01" "$SUBNET_PRIV02"
```
### 4. 構築確認
```bash
# サブネットグループの確認
aws --endpoint-url=http://localhost:4566 rds describe-db-subnet-groups --db-subnet-group-name sample-db-subnet
```

### 考察・ハマりポイント

- **サブネットグループの重要性:** -  RDSを起動するには、異なるAZに属する最低2つのサブネットが必要となる。これにより、AWS側で障害が発生した際のフェイルオーバー（マルチAZ）が可能になる。

- **LocalStackでの挙動:** -  LocalStack上でRDSを起動する場合、実際にはDockerコンテナが立ち上がるため、describe-db-instances で Available になるまで数分かかる場合がある。

```
# DB用のセキュリティグループ作成（未作成なら）
# DB_SG_ID=$(aws ec2 create-security-group --group-name sample-sg-db --description "Security group for DB" --vpc-id $VPC_ID ...)

# WebサーバーのSGからのアクセスを許可
# aws ec2 authorize-security-group-ingress --group-id $DB_SG_ID --protocol tcp --port 3306 --source-group $WEB_SG_ID
```
