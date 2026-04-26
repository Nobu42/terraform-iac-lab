# WebServer (EC2)　作成
| 項目 | 設定値 | 備考 |
|:---|:---|:---|
| **名前 (Name)** | `sample-ec2-web01` / `sample-ec2-web02` | 2台構成 |
| **Amazon Machine Image (AMI)** | `ami-07b643b5e45e` | LocalStack専用 Amazon Linux 2 |
| **インスタンスタイプ** | `t2.micro` | 適宜 |
| **キーペア** | `nobu` | 踏み台サーバーと共通 |
| **VPC** | `sample-vpc` | |
| **サブネット** | `sample-subnet-private01` (web01用)<br>`sample-subnet-private02` (web02用) | マルチAZ配置 |
| **パブリックIPの自動割り当て** | **無効化** | プライベートサブネットのため |
| **セキュリティグループ** | `default` | 必要に応じて後ほど修正 |
### 鍵の作成
```
# Enter file in which to save... → 何も打たずに Enter
# Enter passphrase... → 何も打たずに Enter
# Enter same passphrase... → 何も打たずに Enter
ssh-keygen -t ed25519

# Ubuntuへ転送
ssh-copy-id nobu@192.168.40.100
```

### macの~/.bashrc追記

```
# ls-startでlocalstackスタート！
alias ls-start="ssh nobu@192.168.40.100 'bash ~/start_terraform.sh'"
# lsp でUbuntuのEC2インスタンスに接続するためのポート情報を出力
alias lsp="ssh nobu@192.168.40.100 'docker ps --filter name=localstack-ec2 --format \"table {{.Names}}\t{{.Ports}}\"'"
```
### UbuntuServerのホームディレクトリに以下を配置しておく
```
#!/bin/bash
# Ubuntu側の ~/setup_user.sh

TARGET_ID=$1  # 第一引数にインスタンスIDをもらう

if [ -z "$TARGET_ID" ]; then
    echo "Usage: ./setup_user.sh i-xxxxxx"
    exit 1
fi

CONTAINER_NAME="localstack-ec2.${TARGET_ID}"

echo "👤 Setting up ec2-user for $CONTAINER_NAME..."

docker exec -u root "$CONTAINER_NAME" bash -c '
    useradd -m -s /bin/bash ec2-user && \
    echo "ec2-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/ec2-user/.ssh && \
    cp /root/.ssh/authorized_keys /home/ec2-user/.ssh/ && \
    chown -R ec2-user:ec2-user /home/ec2-user/.ssh && \
    chmod 700 /home/ec2-user/.ssh && \
    chmod 600 /home/ec2-user/.ssh/authorized_keys
'
```
### mac側の~/.ssh/config
```
nobu learning_aws$ cat ~/.ssh/config
# --- (1) 踏み台サーバー (Bastion) ---
Host bastion
    HostName 192.168.40.100
    User ec2-user
    Port 18534                # ここを lsp で確認した bastion のポートに！
    IdentityFile ~/terraform-iac-lab/learning_aws/nobu.pem

# --- (2) Webサーバー 01 ---
Host web01
    HostName 172.17.0.4       # ec2_status.sh で確認した IP
    User ec2-user
    IdentityFile ~/terraform-iac-lab/learning_aws/nobu.pem
    ProxyJump bastion         # 最近の SSH では ProxyCommand よりこれが標準！

# --- (3) Webサーバー 02 ---
Host web02
    HostName 172.17.0.5       # ec2_status.sh で確認した IP
    User ec2-user
    IdentityFile ~/terraform-iac-lab/learning_aws/nobu.pem
    ProxyJump bastion
```

```
#!/bin/bash
# Webサーバー01 (Private Subnet 1)
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
```
