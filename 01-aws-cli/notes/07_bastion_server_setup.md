# 07 Bastion Server Setup

## 目的

AWS CLIで踏み台サーバー用のEC2インスタンスを作成する。

踏み台サーバーは、Public Subnetに配置し、Private Subnet内のサーバーへSSH接続するための入口として利用する。Private Subnet内のEC2へ直接Public IPを付与せず、管理用通信を踏み台サーバー経由に集約することで、外部公開範囲を小さくできる。

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース: Key Pair, EC2
- 前提:
  - `sample-vpc` が作成済みであること
  - `sample-subnet-public01` が作成済みであること
  - `sample-sg-bastion` が作成済みであること
  - Public SubnetのRoute TableがInternet Gatewayへ向いていること

## 設計値

| 項目 | 値 |
| :--- | :--- |
| インスタンス名 | sample-ec2-bastion |
| 配置先Subnet | sample-subnet-public01 |
| Security Group | sample-sg-bastion |
| AMI | Amazon Linux 2023 latest AMI |
| インスタンスタイプ | t3.micro |
| Key Pair | nobu |
| SSHユーザー | ec2-user |
| Public IP | 自動割当 |
| Projectタグ | terraform-iac-lab |
| Environmentタグ | learning |

## スクリプト

- [07_bastion_server_setup.sh](../scripts/07_bastion_server_setup.sh)

## 実行コマンド

```bash
./07_bastion_server_setup.sh
```

## 確認コマンド

```bash
aws ec2 describe-instances \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-ec2-bastion \
  --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name,Type:InstanceType,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,Subnet:SubnetId}' \
  --output table
```

## SSH接続確認

スクリプト実行後に表示されたPublic IPを指定してSSH接続する。

```bash
ssh -i nobu.pem ec2-user@<Public IP>
```

例:

```bash
ssh -i nobu.pem ec2-user@xxx.xxx.xxx.xxx
```

## 実AWSでの実行結果

Public Subnetに踏み台サーバーを作成し、Public IPとPrivate IPが割り当てられた。

| Name | State | Type | Public IP | Private IP |
| :--- | :--- | :--- | :--- | :--- |
| sample-ec2-bastion | running | t3.micro | 割り当て済み | 割り当て済み |

## 学んだこと

- EC2を起動するには、AMI、インスタンスタイプ、Key Pair、Subnet、Security Groupが必要
- Public Subnetで `--associate-public-ip-address` を指定すると、EC2にPublic IPを割り当てられる
- Amazon Linux 2023では、SSHユーザーとして通常 `ec2-user` を使用する
- Key Pairを作成すると秘密鍵が一度だけ取得できるため、`.pem` ファイルの管理が重要になる
- `.pem` ファイルはGit管理してはいけない
- 実AWSではLocalStack用AMIを利用できないため、SSM Parameter StoreからAmazon Linux 2023の最新AMIを取得した
- 無料枠対象のインスタンスタイプはアカウント作成時期やAWS側のFree Tier仕様により変わるため、事前に確認が必要

## Free Tierに関するメモ

初回実行時、`t2.micro` でEC2を起動しようとしたところ、以下のエラーが発生した。

```text
The specified instance type is not eligible for Free Tier.
```

そのため、無料枠対象のインスタンスタイプを確認し、`t3.micro` に変更して実行した。

無料枠対象のインスタンスタイプは以下のコマンドで確認できる。

```bash
aws ec2 describe-instance-types \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=free-tier-eligible,Values=true \
  --query 'InstanceTypes[*].InstanceType' \
  --output text
```

## 注意事項

EC2インスタンスは起動中に課金対象となる。学習が終わったら停止または削除する。

Public IPv4アドレスも課金対象となる場合があるため、不要なEC2やElastic IPを放置しない。

`nobu.pem` は秘密鍵であり、GitHubにpushしてはいけない。`.gitignore` に以下を追加して管理対象外にする。

```gitignore
*.pem
*.key
```

Security GroupでSSHを `0.0.0.0/0` に開放すると、インターネット全体からSSH接続を受け付ける状態になる。実運用では自分のグローバルIP `/32` に制限する。

## 削除時の注意

Bastion Serverを削除する場合は、EC2をterminateする。

```bash
aws ec2 terminate-instances \
  --profile learning \
  --region ap-northeast-1 \
  --instance-ids <Instance ID>
```

Key Pairも不要であれば削除する。

```bash
aws ec2 delete-key-pair \
  --profile learning \
  --region ap-northeast-1 \
  --key-name nobu
```

ローカルの秘密鍵ファイルも不要であれば削除する。

```bash
rm -f nobu.pem
```

