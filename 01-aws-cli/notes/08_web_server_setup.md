# WebServer 作成

## 1. インフラ設計

### EC2 インスタンス共通設計
| 項目 | 設定内容 |
| :--- | :--- |
| **AMI ID** | `ami-07b643b5e45e` (Amazon Linux 2 / LocalStack用) |
| **インスタンスタイプ** | `t2.micro` |
| **キーペア** | `nobu` |
| **パブリックIP** | 無効（Private Subnet配置のため） |
| **セキュリティグループ** | `default` (VPC内通信許可) |
| **OS ユーザー** | `ec2-user` |

### 個別識別情報
| サーバー名 | 名前タグ | 配置サブネット | 用途 |
| :--- | :--- | :--- | :--- |
| **Webサーバー 01** | `sample-ec2-web01` | `sample-subnet-private01` | アプリケーション実行 (AZ-a) |
| **Webサーバー 02** | `sample-ec2-web02` | `sample-subnet-private02` | アプリケーション実行 (AZ-c) |

## 自動化ロジック

本スクリプトでは、LocalStack環境特有の動的な挙動に対応するため、以下の自動化機能を実装している。

* **動的ポート・IP追従**: 起動のたびに変わるBastionの転送ポート、およびWebサーバーのプライベートIPをAWS CLIで取得。
* **SSH Config 自動更新**: `sed` コマンドを用い、Macローカルの `~/.ssh/config` を動的に書き換える。これにより、常に `ssh web01` などのショートカット名で接続が可能。
* **SSH Key 競合回避**: 新規起動時の `Host key verification failed` を防ぐため、`ssh-keygen -R` による既知のホスト情報の自動削除を実施。

```
#!/bin/bash

# --- 0. 必要なサブネットIDを再取得 ---
PRI01_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-private01 --query 'Subnets[0].SubnetId' --output text)
PRI02_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-private02 --query 'Subnets[0].SubnetId' --output text)

# --- 1. Webサーバー起動 (run-instancesの戻り値を確実に変数に保持) ---
echo "Launching Web servers..."

WEB01_ID=$(aws ec2 run-instances \
    --image-id ami-07b643b5e45e \
    --count 1 \
    --instance-type t2.micro \
    --key-name nobu \
    --subnet-id $PRI01_ID \
    --no-associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sample-ec2-web01}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

WEB02_ID=$(aws ec2 run-instances \
    --image-id ami-07b643b5e45e \
    --count 1 \
    --instance-type t2.micro \
    --key-name nobu \
    --subnet-id $PRI02_ID \
    --no-associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sample-ec2-web02}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

# 踏み台サーバーのIDも取得しておく
BASTION_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=sample-ec2-bastion" --query 'Reservations[].Instances[].InstanceId' --output text)

echo "Created Web01: $WEB01_ID"
echo "Created Web02: $WEB02_ID"

# --- 2. インスタンスの起動待機 ---
# タグ検索で再取得するとNoneになるリスクがあるため、上記で取得したIDをそのまま使用します
echo "Waiting for all instances to be running..."
aws ec2 wait instance-running --instance-ids $BASTION_ID $WEB01_ID $WEB02_ID

# LocalStackのメタデータ反映を確実にするため、少しだけ猶予を置く
sleep 2

# --- 3. ユーザーセットアップ ---
for id in $BASTION_ID $WEB01_ID $WEB02_ID; do
    echo "Processing $id..."
    ssh nobu@192.168.40.100 "bash ~/setup_user.sh $id"
done

# --- 4. BastionのSSHポート更新 (.ssh/config) ---
# Docker経由のポートマッピングを取得
NEW_PORT=$(ssh nobu@192.168.40.100 "docker ps" | grep "$BASTION_ID" | sed -E 's/.*:([0-9]+)->22.*/\1/')

if [ -n "$NEW_PORT" ]; then
    sed -i '' -e "/Host bastion/,/Port/ s/Port [0-9]*/Port $NEW_PORT/" ~/.ssh/config
    echo " Success! Bastion Config updated to Port $NEW_PORT"
else
    echo " Error: Could not find port for ID $BASTION_ID"
fi

# --- 5. SSHホストキーの掃除 ---
echo "Cleaning up old SSH host keys..."
# 踏み台(Ubuntu側)のIPと、各コンテナの内部想定IPを掃除
ssh-keygen -R 192.168.40.100 > /dev/null 2>&1
for ip in 172.17.0.3 172.17.0.4 172.17.0.5; do
    ssh-keygen -R $ip > /dev/null 2>&1
done

# --- 6. WebサーバーのプライベートIP取得と config 更新 ---
# describe-instancesの結果を1回で取得して、タイミング問題を回避
WEB_INFO=$(aws ec2 describe-instances --instance-ids $WEB01_ID $WEB02_ID --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value | [0], PrivateIpAddress]' --output text)

IP01=$(echo "$WEB_INFO" | grep "sample-ec2-web01" | awk '{print $2}')
IP02=$(echo "$WEB_INFO" | grep "sample-ec2-web02" | awk '{print $2}')

if [ -n "$IP01" ]; then sed -i '' -e "/Host web01/,/HostName/ s/HostName .*/HostName $IP01/" ~/.ssh/config; fi
if [ -n "$IP02" ]; then sed -i '' -e "/Host web02/,/HostName/ s/HostName .*/HostName $IP02/" ~/.ssh/config; fi

echo "-------------------------------------------"
echo " Web01 IP: $IP01"
echo " Web02 IP: $IP02"
echo " .ssh/config updated successfully."
echo "-------------------------------------------"

# 最終確認の表示
aws ec2 describe-instances \
    --instance-ids $BASTION_ID $WEB01_ID $WEB02_ID \
    --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value | [0], Status:State.Name, PrivateIP:PrivateIpAddress}' \
    --output table
```
