# LoadBalancer 作成

## 1. インフラ設計

### Application Load Balancer (ALB) 設計
| 項目 | 設定内容 |
| :--- | :--- |
| **名前** | `sample-elb` |
| **スキーム** | `internet-facing` (インターネット向け) |
| **タイプ** | `application` |
| **サブネット** | `public01`, `public02` (マルチAZ構成) |
| **セキュリティグループ** | `sample-sg-elb` (80/443許可) |

### ターゲットグループ (Target Group) 設計
| 項目 | 設定内容 |
| :--- | :--- |
| **名前** | `sample-tg` |
| **プロトコル** | `HTTP` |
| **ポート** | `3000` (アプリケーション待機ポート) |
| **ターゲット** | `sample-ec2-web01`, `sample-ec2-web02` |
| **ヘルスチェックパス** | `/` |

## 2. 実装のポイント（多段防御の設定）

* **SG連携**: WebサーバーのSGに対して、IP帯(CIDR)ではなく**ALBのSG IDをソースとして**通信を許可。これにより、ALBを経由しない不正な直接アクセスを遮断する。
* **マルチAZ冗長化**: パブリックサブネット2系統にまたがってALBを配置し、可用性を確保。

## 3. セットアップスクリプト

```
#!/bin/bash

# --- 1. 必要な ID を再取得して変数に叩き込む ---
# タグ名から動的に取得することで、環境再構築後でもそのまま動くようにしている
VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=sample-vpc --query 'Vpcs[0].VpcId' --output text)
PUB01_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public01 --query 'Subnets[0].SubnetId' --output text)
PUB02_ID=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=sample-subnet-public02 --query 'Subnets[0].SubnetId' --output text)
WEB01_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=sample-ec2-web01 --query 'Reservations[0].Instances[0].InstanceId' --output text)
WEB02_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=sample-ec2-web02 --query 'Reservations[0].Instances[0].InstanceId' --output text)

# --- 2. ターゲットグループを作成 ---
# Webサーバーが3000番で待機している想定の設定
TG_ARN=$(aws elbv2 create-target-group \
    --name sample-tg \
    --protocol HTTP \
    --port 3000 \
    --vpc-id $VPC_ID \
    --health-check-protocol HTTP \
    --health-check-path / \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo " Target Group Created: $TG_ARN"

# --- 3. Webサーバーを登録（2台まとめて） ---
aws elbv2 register-targets \
    --target-group-arn $TG_ARN \
    --targets Id=$WEB01_ID Id=$WEB02_ID

echo " Web01 and Web02 registered to Target Group."

# --- 4. LB用セキュリティグループの ID を取得 ---
SG_ELB_ID=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values=sample-sg-elb \
    --query 'SecurityGroups[0].GroupId' --output text)

# --- 5. ロードバランサー（ALB）本体の作成 ---
LB_ARN=$(aws elbv2 create-load-balancer \
    --name sample-elb \
    --subnets $PUB01_ID $PUB02_ID \
    --security-groups $SG_ELB_ID \
    --scheme internet-facing \
    --type application \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

echo " Load Balancer Created: $LB_ARN"

# --- 6. リスナーの作成（80番ポートの受付開始） ---
echo "Creating Listener (Port 80)..."
aws elbv2 create-listener \
    --load-balancer-arn $LB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN

# --- 7. セキュリティグループの連動（穴あけ） ---
# Webサーバー側で「ALBのSGからの通信」を許可するように設定を書き換えます
# Webサーバー用SGのIDを名前から確実に取得
SG_WEB_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=sample-sg-web --query 'SecurityGroups[0].GroupId' --output text)

for target_id in $WEB01_ID $WEB02_ID; do
    echo "Updating instance $target_id..."

    # ① インスタンスに SG を確実に紐付ける
    aws ec2 modify-instance-attribute --instance-id $target_id --groups $SG_WEB_ID

    # ② ALB からの通信（3000番）を許可するルールを追加（既にあればスキップされる）
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_WEB_ID \
        --protocol tcp --port 3000 --source-group $SG_ELB_ID 2>/dev/null
done

# --- 8. アクセス用URLと次の手順を表示 ---
DNS_NAME=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $LB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

echo "------------------------------------------------"
echo " Setup Complete!"
echo "------------------------------------------------"
echo "1. Run this in a separate terminal to tunnel LocalStack:"
echo "   ssh -L 4566:192.168.40.100:4566 nobu@192.168.40.100"
echo ""
echo "2. Add this to your Mac /etc/hosts (if not already done):"
echo "   127.0.0.1 sample-elb.elb.localhost.localstack.cloud"
echo ""
echo "3. Access URL in your browser:"
echo "   http://sample-elb.elb.localhost.localstack.cloud:4566"
echo "------------------------------------------------"
```

## 4. 疎通確認手順

構築したALBを経由して、Private Subnet内のWebサーバーにアクセスできるか確認する。

### 4.1 Webサーバー側での準備（ダミーサーバー起動）
Webサーバー（例：Web01）にログインし、テスト用のHTMLファイルを作成して簡易サーバーを起動する。

```bash
# Webサーバー内で実行
echo "Hello from WebServer 01 (Python 2.7)" > index.html

# Amazon Linux 2 (Python 2.7系) の場合の起動コマンド
python -m SimpleHTTPServer 3000
```

### 4.2 Mac側でのトンネル疎通（L7ルーティング）

LocalStackのALBは名前解決（Hostヘッダー）を利用するため、以下の手順でMacからの経路を確保する。

#### ① SSHトンネルの構築

Macの4566番ポートを、LocalStackが動いているUbuntuの4566番へ転送する。
```
# Macの別ターミナルで実行（疎通確認中は維持すること）
ssh -L 4566:localhost:4566 nobu@192.168.40.100
```

#### ② Macのhosts設定

ブラウザからの名前解決を有効にするため、ALBのDNS名をlocalhostに向ける。
```
# Macで実行
echo "127.0.0.1 sample-elb.elb.localhost.localstack.cloud" | sudo tee -a /etc/hosts
```

#### ④ curl、ブラウザでの最終確認

curlで実行
```
# Macで実行
curl -v http://localhost:4566 -H "Host: sample-elb.elb.localhost.localstack.cloud"
```

以下のURLをブラウザで開き、「Hello from WebServer 01」が表示されれば成功。

http://sample-elb.elb.localhost.localstack.cloud:4566

