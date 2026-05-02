# 09 Load Balancer Setup

## 目的

AWS CLIでApplication Load Balancerを作成し、Private Subnet上のWebサーバー2台へHTTPリクエストを振り分ける。

ALBはPublic Subnetに配置し、インターネットからのHTTPアクセスを受け付ける。受け取ったリクエストはListenerの設定に従ってTarget Groupへ転送し、Target Groupに登録されたWeb01/Web02の3000番ポートへ振り分ける。

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース: Target Group, Application Load Balancer, Listener
- 前提:
  - `sample-vpc` が作成済みであること
  - `sample-subnet-public01` が作成済みであること
  - `sample-subnet-public02` が作成済みであること
  - `sample-ec2-web01` が起動済みであること
  - `sample-ec2-web02` が起動済みであること
  - `sample-sg-elb` が作成済みであること
  - `sample-sg-web` で `sample-sg-elb` からの3000/tcpを許可していること
  - Webサーバー上で3000番ポートのHTTPサーバーが起動していること

## 設計値

| 項目 | 値 |
| :--- | :--- |
| ALB名 | sample-elb |
| ALB種別 | Application Load Balancer |
| Scheme | internet-facing |
| 配置先Subnet | sample-subnet-public01, sample-subnet-public02 |
| Security Group | sample-sg-elb |
| Listener | HTTP:80 |
| Target Group | sample-tg |
| Target Type | instance |
| Target Protocol | HTTP |
| Target Port | 3000 |
| Health Check Path | / |

## Security Group設計

| Security Group | 用途 | 許可する通信 | 送信元 |
| :--- | :--- | :--- | :--- |
| sample-sg-elb | ALB | HTTP 80/tcp | 0.0.0.0/0 |
| sample-sg-elb | ALB | HTTPS 443/tcp | 0.0.0.0/0 |
| sample-sg-web | Webサーバー | App 3000/tcp | sample-sg-elb |

## 通信経路

```text
Browser
  -> ALB :80
  -> Listener :80
  -> Target Group sample-tg
  -> Web01 / Web02 :3000
```

## スクリプト

- [09_LoadBalancer_setup.sh](../scripts/09_LoadBalancer_setup.sh)

## 実行コマンド

```bash
./09_LoadBalancer_setup.sh
```

## 確認コマンド

ALBのDNS名を確認する。

```bash
aws elbv2 describe-load-balancers \
  --profile learning \
  --region ap-northeast-1 \
  --names sample-elb \
  --query 'LoadBalancers[0].DNSName' \
  --output text
```

Target Group ARNを取得する。

```bash
TG_ARN=$(aws elbv2 describe-target-groups \
  --profile learning \
  --region ap-northeast-1 \
  --names sample-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)
```

Target Healthを確認する。

```bash
aws elbv2 describe-target-health \
  --profile learning \
  --region ap-northeast-1 \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
  --output table
```

ALBの状態を確認する。

```bash
aws elbv2 describe-load-balancers \
  --profile learning \
  --region ap-northeast-1 \
  --names sample-elb \
  --query 'LoadBalancers[*].{Name:LoadBalancerName,DNSName:DNSName,State:State.Code,Scheme:Scheme,Type:Type,VpcId:VpcId}' \
  --output table
```

## Webサーバーの簡易HTTP起動

ALBの疎通確認用に、Web01/Web02でPythonの簡易HTTPサーバーを3000番ポートで起動した。

```bash
echo "Hello World!" > index.html
python3 -m http.server 3000
```

Python 3では、Python 2の `SimpleHTTPServer` は利用できない。
Amazon Linux 2023では以下を使う。

```bash
python3 -m http.server 3000
```

バックグラウンドで起動する場合:

```bash
nohup python3 -m http.server 3000 > server.log 2>&1 &
```

確認:

```bash
ss -lntp | grep 3000
```

## ALB疎通確認

ALBのDNS名へブラウザからアクセスし、Private Subnet上のWebサーバー2台へリクエストが振り分けられることを確認した。

```text
http://<ALB DNS名>
```

確認できたレスポンス例:

```html
<html>
  <body>
    <h1>Hello World!</h1>
  </body>
</html>
```

```html
<html>
  <body>
    <h1>Hello World! from Web02!</h1>
  </body>
</html>
```

Web01とWeb02で異なるHTMLを返すことで、ALBがTarget Group内の複数インスタンスへリクエストを振り分けていることを確認した。

## 実AWSでの実行結果

ALB、Target Group、Listenerを作成し、Web01/Web02をTarget Groupへ登録した。

| 項目 | 結果 |
| :--- | :--- |
| ALB | 作成済み |
| Listener | HTTP:80 |
| Target Group | sample-tg |
| Target Port | 3000 |
| Web01 Target Health | healthy |
| Web02 Target Health | healthy |
| ブラウザ疎通 | 確認済み |

Target Health確認結果:

| Target | Port | State |
| :--- | :--- | :--- |
| Web01 | 3000 | healthy |
| Web02 | 3000 | healthy |

## 学んだこと

- ALBはPublic Subnetに配置し、インターネットからの入口として利用できる
- ALBのSecurity Groupで、外部からのHTTP/HTTPSアクセスを許可する
- Listenerは、ALBが受け取った通信をどのTarget Groupへ転送するかを決める
- Target Groupには複数のEC2インスタンスを登録できる
- Target Healthが `healthy` になるには、Webサーバー側でヘルスチェック対象のパスに正常応答する必要がある
- WebサーバーがPrivate Subnetにあっても、ALB経由でHTTPアクセスできる
- Webサーバー側Security Groupでは、ALB用Security Groupからの3000/tcpを許可する必要がある
- How-to本などではWebサーバー側にdefault Security Groupを利用する例もあるが、この構成では用途を明確にするため `sample-sg-web` を作成している

## 注意事項

ALBは課金対象である。学習が終わったら削除する。

Webサーバー側で3000番ポートのアプリケーションが起動していない場合、Target Healthは `unhealthy` になる。

今回のスクリプトでは、`sample-sg-elb` と `sample-sg-web` を分けている。
`sample-sg-elb` はインターネットからALBへのHTTP/HTTPSを許可し、`sample-sg-web` はALBからWebサーバーへの3000番ポートを許可する。

同じスクリプトを複数回実行すると、同じ名前のTarget GroupやALBを作成しようとしてエラーになる可能性がある。

## 削除時の注意

ALB関連リソースは依存関係があるため、以下の順序で削除する。

1. Listenerを削除する
2. ALBを削除する
3. Target Groupを削除する
4. 必要に応じてWeb EC2やSecurity Groupを削除する

Listener ARNを取得する例:

```bash
LB_ARN=$(aws elbv2 describe-load-balancers \
  --profile learning \
  --region ap-northeast-1 \
  --names sample-elb \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

LISTENER_ARN=$(aws elbv2 describe-listeners \
  --profile learning \
  --region ap-northeast-1 \
  --load-balancer-arn "$LB_ARN" \
  --query 'Listeners[0].ListenerArn' \
  --output text)
```

Listener削除:

```bash
aws elbv2 delete-listener \
  --profile learning \
  --region ap-northeast-1 \
  --listener-arn "$LISTENER_ARN"
```

ALB削除:

```bash
aws elbv2 delete-load-balancer \
  --profile learning \
  --region ap-northeast-1 \
  --load-balancer-arn "$LB_ARN"
```

Target Group削除:

```bash
TG_ARN=$(aws elbv2 describe-target-groups \
  --profile learning \
  --region ap-northeast-1 \
  --names sample-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

aws elbv2 delete-target-group \
  --profile learning \
  --region ap-northeast-1 \
  --target-group-arn "$TG_ARN"
```

