## 踏み台サーバー（Bastion）の作成

### キーペア設計
| 項目 | 設定内容 |
| :--- | :--- |
| **名前** | `nobu` |
| **タイプ** | RSA |
| **形式** | `.pem` |

### EC2 インスタンス設計：sample-ec2-bastion
| 項目 | 設定内容 |
| :--- | :--- |
| **名前タグ** | `sample-ec2-bastion` |
| **AMI ID** | `ami-0ff227f0771efc640` |
| **タイプ** | `t2.micro` |
| **キーペア** | `nobu` |
| **サブネット** | `sample-subnet-public01` |
| **パブリックIP** | 有効 |
| **セキュリティグループ** | `sample-sg-bastion` |

```
# CLIでAMI IDを確認するコマンド
aws ec2 describe-images --query 'Images[*].[ImageId,Name]' --output table
```

```
# CLIでAMIを絞り込む方法(--filtersで絞り込み)
aws ec2 describe-images \
    --filters "Name=name,Values=amzn2-ami-hvm*" \
    --query 'Images[*].[ImageId,Name]' \
    --output table

BASTION_ID=$(aws ec2 run-instances \
    --image-id ami-0ff227f0771efc640 \
    --count 1 \
    --instance-type t2.micro \
    --key-name nobu \
    --security-group-ids $SG_BASTION_ID \
    --subnet-id $PUB01_ID \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sample-ec2-bastion}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Bastion Instance Created: $BASTION_ID"
```
```

# LocalStack(AWS)側から既存のキーペアを削除（エラーが出ても無視する）
aws ec2 delete-key-pair --key-name nobu > /dev/null 2>&1
# mac側（クライアント）も削除
rm -f nobu.pem
# 1. キーペアの作成と保存
aws ec2 create-key-pair \
    --key-name nobu \
    --query 'KeyMaterial' \
    --output text > nobu.pem

# パーミッションを自分だけが読み取れる設定に変更（必須）
chmod 400 nobu.pem

# 2. 踏み台サーバーの起動
# --associate-public-ip-address でパブリックIPを有効化する
# 踏み台サーバーの起動
# 【重要】--image-id を LocalStack が「コンテナ」として認識できる ID に変更する
# Amazon Linux 2 の LocalStack 用デフォルト ID: ami-07b643b5e45e
BASTION_ID=$(aws ec2 run-instances \
    --image-id ami-07b643b5e45e \
    --count 1 \
    --instance-type t2.micro \
    --key-name nobu \
    --security-group-ids $SG_BASTION_ID \
    --subnet-id $PUB01_ID \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sample-ec2-bastion}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Bastion Instance Created: $BASTION_ID"
```
### 起動確認

```
aws ec2 describe-instances \
    --instance-ids $BASTION_ID \
    --query 'Reservations[0].Instances[0].{Status:State.Name, PublicIP:PublicIpAddress}' \
    --output table
```
### 接続確認
```
# Ubuntu側でdocker psで以下を確認
# 0.0.0.0:60577->22/tcp, [::]:60577->22/tcp

# Macのターミナルから実行
ssh -i nobu.pem -p 60577 root@192.168.40.100

# 1. OSのリリース情報を確認（これで Amazon Linux 2 であることが分かる）
cat /etc/system-release

# 2. ネットワーク設定を確認（IPが見えるはず）
ip addr show eth0

# 3. CPU情報を確認
cat /proc/cpuinfo | grep "model name"
```
### ユーザー作成（本物に似せるため、ec2-userを作成する）
```
# 1. ec2-user という名前のユーザーを作成
useradd ec2-user

# 2. ec2-user が sudo（管理者権限）を使えるように設定
# (LocalStackのコンテナ環境では /etc/sudoers をいじるより、グループ追加が手っ取り早い)
yum install -y sudo
echo "ec2-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 3. ec2-user に切り替える
su - ec2-user
```
```
# 1. ec2-userのSSH設定ディレクトリを作成
mkdir -p /home/ec2-user/.ssh
chmod 700 /home/ec2-user/.ssh

# 2. rootが持っている「許可された鍵リスト」を ec2-user にコピー
cp /root/.ssh/authorized_keys /home/ec2-user/.ssh/
chown -R ec2-user:ec2-user /home/ec2-user/.ssh
chmod 600 /home/ec2-user/.ssh/authorized_keys

# パスワードを「password」に設定する場合
echo "ec2-user:password" | chpasswd
```

