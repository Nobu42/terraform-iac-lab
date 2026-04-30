# 06 Security Group Setup

## 目的

AWS CLIでSecurity Groupを作成し、踏み台サーバー用とロードバランサー用の通信許可ルールを設定する。

Security Groupは、EC2やALBなどに適用する仮想ファイアウォールである。インバウンド通信とアウトバウンド通信を制御し、必要な通信だけを許可する。

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース: Security Group
- 前提:
  - `sample-vpc` が作成済みであること

## Security Group設計

| 用途 | Security Group名 | 許可する通信 | 送信元 |
| :--- | :--- | :--- | :--- |
| 踏み台サーバー | sample-sg-bastion | SSH 22/tcp | 0.0.0.0/0 |
| ロードバランサー | sample-sg-elb | HTTP 80/tcp | 0.0.0.0/0 |
| ロードバランサー | sample-sg-elb | HTTPS 443/tcp | 0.0.0.0/0 |

## スクリプト

- [06_security_group_setup.sh](../scripts/06_security_group_setup.sh)

## 実行コマンド

```bash
./06_security_group_setup.sh
```

## 確認コマンド

```bash
aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=group-name,Values=sample-sg-bastion,sample-sg-elb \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,Description:Description,Rules:IpPermissions[*].{Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,Cidr:IpRanges[0].CidrIp,RuleDescription:IpRanges[0].Description}}' \
  --output table
```

## 実AWSでの実行結果

踏み台サーバー用Security Groupと、ロードバランサー用Security Groupを作成した。

| Name | 用途 | 許可ルール |
| :--- | :--- | :--- |
| sample-sg-bastion | 踏み台サーバー | 22/tcp from 0.0.0.0/0 |
| sample-sg-elb | ロードバランサー | 80/tcp from 0.0.0.0/0, 443/tcp from 0.0.0.0/0 |

## 学んだこと

- Security GroupはVPCに紐づくリソースである
- EC2やALBにSecurity Groupを適用することで、許可する通信を制御できる
- `authorize-security-group-ingress` でインバウンドルールを追加できる
- ALB用Security Groupでは、外部からのHTTP/HTTPSアクセスを許可する
- 踏み台サーバー用Security GroupではSSHを許可するが、実運用では送信元IPを絞る必要がある
- Security Groupのアウトバウンド通信は、デフォルトで全許可になっている
- Terraform化する場合、Security Group本体とSecurity Group Ruleを分けて管理する設計もできる

## 注意事項

今回の学習用スクリプトでは、踏み台サーバーへのSSHを `0.0.0.0/0` から許可している。

```text
22/tcp from 0.0.0.0/0
```

これはインターネット全体からSSH接続を受け付ける設定であり、実運用では推奨されない。実運用では、自宅や作業場所のグローバルIPに限定する。

例:

```bash
SSH_ALLOWED_CIDR="xxx.xxx.xxx.xxx/32"
```

自分のグローバルIPは以下で確認できる。

```bash
curl -s https://checkip.amazonaws.com
```

同じスクリプトを複数回実行すると、同じGroup NameのSecurity Groupを作成しようとしてエラーになる可能性がある。

## 削除時の注意

Security Groupは、EC2、ALB、RDSなどのリソースに関連付けられている間は削除できない。

削除時は、先にSecurity Groupを利用しているリソースを削除または関連付け解除してから、Security Groupを削除する。

削除順序の例:

1. ALBを削除する
2. EC2を削除する
3. RDSを削除する
4. Security Groupを削除する

