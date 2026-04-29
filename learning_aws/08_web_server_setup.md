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
# Webサーバー01 (Private Subnet 1)
# --- 0. 必要なサブネットIDを再取得 ---
PRI01_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-private01 --query 'Subnets[0].SubnetId' --output text)
PRI02_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-private02 --query 'Subnets[0].SubnetId' --output text)

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

# Webサーバー02 (Private Subnet 2)
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

echo "Created Web01: $WEB01_ID"
echo "Created Web02: $WEB02_ID"

# Nameタグを指定してIDを自動取得する魔法のコマンド（Mac側）
BASTION_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=sample-ec2-bastion" --query 'Reservations[].Instances[].InstanceId' --output text)
WEB01_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=sample-ec2-web01" --query 'Reservations[].Instances[].InstanceId' --output text)
WEB02_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=sample-ec2-web02" --query 'Reservations[].Instances[].InstanceId' --output text)

# インスタンス 3 台すべてが「running」状態になるまで待機
echo "Waiting for all instances to be running..."
aws ec2 wait instance-running --instance-ids $BASTION_ID $WEB01_ID $WEB02_ID

for id in $BASTION_ID $WEB01_ID $WEB02_ID; do
    echo "Processing $id..."
    ssh nobu@192.168.40.100 "bash ~/setup_user.sh $id"
done

# 1. AWS CLIを使って、Nameタグが "sample-ec2-bastion" のIDを取得
CURRENT_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=sample-ec2-bastion" --query 'Reservations[].Instances[].InstanceId' --output text)

# 2. そのIDを元に、Ubuntu側のDockerからポートを取得
NEW_PORT=$(ssh nobu@192.168.40.100 "docker ps" | grep "$CURRENT_ID" | sed -E 's/.*:([0-9]+)->22.*/\1/')

if [ -n "$NEW_PORT" ]; then
    sed -i '' -e "/Host bastion/,/Port/ s/Port [0-9]*/Port $NEW_PORT/" ~/.ssh/config
    echo " Success! Config updated to Port $NEW_PORT (ID: $CURRENT_ID)"
else
    echo " Error: Could not find port for ID $CURRENT_ID"
fi

# 以前の接続情報を掃除（172.17.0.4 や 172.17.0.5 などの競合を防ぐ。本番では注意する）
echo "Cleaning up old SSH host keys..."
ssh-keygen -R 192.168.40.100          # 踏み台のIP
ssh-keygen -R 172.17.0.3              # Bastionの内部IP（一応）
ssh-keygen -R 172.17.0.4              # Web01
ssh-keygen -R 172.17.0.5              # Web02

aws ec2 describe-instances \
    --instance-ids $BASTION_ID \
    --query 'Reservations[0].Instances[0].{Status:State.Name, PublicIP:PublicIpAddress}' \
    --output table
# スクリプトの最後にこれを足すと、.ssh/configが常に最新に！
NEW_IP01=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=sample-ec2-web01" --query 'Reservations[].Instances[].PrivateIpAddress' --output text)
NEW_IP02=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=sample-ec2-web02" --query 'Reservations[].Instances[].PrivateIpAddress' --output text)

sed -i '' -e "/Host web01/,/HostName/ s/HostName .*/HostName $NEW_IP01/" ~/.ssh/config
sed -i '' -e "/Host web02/,/HostName/ s/HostName .*/HostName $NEW_IP02/" ~/.ssh/config
```
