# 08 Web Server Setup

## 目的

AWS CLIでPrivate SubnetにWebサーバー用EC2インスタンスを2台作成する。

WebサーバーはPublic IPを持たせず、Private Subnetに配置する。外部からの直接SSH接続は許可せず、踏み台サーバー経由で管理する。アプリケーション用ポートは、後続で作成するALBからのみ到達できるようにSecurity Groupで制御する。

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース: Security Group, EC2
- 前提:
  - `sample-vpc` が作成済みであること
  - `sample-subnet-private01` が作成済みであること
  - `sample-subnet-private02` が作成済みであること
  - `sample-ec2-bastion` が起動済みであること
  - `sample-sg-bastion` が作成済みであること
  - `sample-sg-elb` が作成済みであること
  - Key Pair `nobu` が作成済みであること
  - ローカルに `nobu.pem` が存在すること

## 設計値

| 項目 | Web01 | Web02 |
| :--- | :--- | :--- |
| インスタンス名 | sample-ec2-web01 | sample-ec2-web02 |
| 配置先Subnet | sample-subnet-private01 | sample-subnet-private02 |
| Public IP | なし | なし |
| AMI | カスタムWebベースAMI または Amazon Linux 2023 latest AMI | カスタムWebベースAMI または Amazon Linux 2023 latest AMI |
| インスタンスタイプ | t3.small | t3.small |
| Key Pair | nobu | nobu |
| SSHユーザー | ec2-user | ec2-user |

## Security Group設計

| Security Group | 用途 | 許可する通信 | 送信元 |
| :--- | :--- | :--- | :--- |
| sample-sg-web | Webサーバー | SSH 22/tcp | sample-sg-bastion |
| sample-sg-web | Webサーバー | App 3000/tcp | sample-sg-elb |

## スクリプト

- [08_Web_server_setup.sh](../scripts/08_Web_server_setup.sh)

## 実行コマンド

```bash
./08_Web_server_setup.sh
```

## AMIの切り替え

`08_Web_server_setup.sh` では、Web EC2作成時に使用するAMIを変数で切り替えられるようにしている。

通常の学習再構築では、AnsibleでRuby、Bundler、nginx、deployユーザーを導入済みのカスタムWebベースAMIを使用する。

```bash
USE_CUSTOM_WEB_AMI=true
CUSTOM_WEB_AMI_ID="ami-00f86224c38cc3b8c"
```

作成済みのカスタムAMI:

```text
AMI ID: ami-00f86224c38cc3b8c
Name  : web-base-ruby336-rails72-20260505-102118
```

カスタムAMIを使用する目的は、日次でAWSリソースを削除、再構築する運用において、Rubyのソースビルド時間を短縮することである。

カスタムAMIには以下を含める。

- Amazon Linux 2023
- 共通パッケージ
- deployユーザー
- nginx
- rbenv
- Ruby 3.3.6
- Bundler

カスタムAMIには以下を含めない。

- Railsアプリケーション本体
- DBパスワード
- SES SMTPパスワード
- secret_key_base
- 投稿画像
- 一時ログ

Amazon Linux 2023の最新AMIから起動したい場合は、以下のように変更する。

```bash
USE_CUSTOM_WEB_AMI=false
```

この場合、スクリプトはSSM Parameter StoreからAmazon Linux 2023の最新AMI IDを取得してEC2を作成する。

## 確認コマンド

```bash
aws ec2 describe-instances \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-ec2-web01,sample-ec2-web02 \
  --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name,Type:InstanceType,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,Subnet:SubnetId}' \
  --output table
```

Webサーバー用Security Groupの確認:

```bash
aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=group-name,Values=sample-sg-web \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,Rules:IpPermissions[*].{Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,SourceGroup:UserIdGroupPairs[0].GroupId,Description:UserIdGroupPairs[0].Description}}' \
  --output table
```

## SSH接続確認

WebサーバーはPrivate Subnetに配置しているため、直接SSH接続しない。踏み台サーバーを経由して接続する。

```bash
ssh -i nobu.pem -J ec2-user@<Bastion Public IP> ec2-user@<Web Private IP>
```

`~/.ssh/config` を利用する場合は、スクリプト末尾に出力されるSSH configブロックを確認し、手動で反映する。

```sshconfig
Host bastion
  HostName <Bastion Public IP>
  User ec2-user
  IdentityFile /path/to/nobu.pem
  IdentitiesOnly yes

Host web01
  HostName <Web01 Private IP>
  User ec2-user
  IdentityFile /path/to/nobu.pem
  IdentitiesOnly yes
  ProxyJump bastion

Host web02
  HostName <Web02 Private IP>
  User ec2-user
  IdentityFile /path/to/nobu.pem
  IdentitiesOnly yes
  ProxyJump bastion
```

反映後は以下で接続できる。

```bash
ssh bastion
ssh web01
ssh web02
```

## 実AWSでの実行結果

Private SubnetにWebサーバーを2台作成した。

| Name | State | Type | Public IP | Private IP |
| :--- | :--- | :--- | :--- | :--- |
| sample-ec2-web01 | running | t3.small | なし | 割り当て済み |
| sample-ec2-web02 | running | t3.small | なし | 割り当て済み |

Webサーバー用Security Groupでは、踏み台サーバーからのSSHと、ALBからのアプリケーション通信のみを許可した。

| 通信 | Port | Source |
| :--- | :--- | :--- |
| SSH | 22/tcp | sample-sg-bastion |
| Application | 3000/tcp | sample-sg-elb |

## 学んだこと

- Private SubnetのEC2にはPublic IPを付与しない構成にできる
- Private SubnetのEC2へ管理接続する場合、踏み台サーバー経由のSSHを利用できる
- Security Groupの送信元にはCIDRだけでなく、別のSecurity Groupを指定できる
- Webサーバー用Security Groupで、SSHはBastion SGからのみ、アプリケーションポートはALB SGからのみ許可する構成にした
- LocalStack用AMIは実AWSでは利用できないため、SSM Parameter StoreからAmazon Linux 2023の最新AMIを取得した
- Ruby導入済みカスタムAMIを使うことで、日次再構築時のRubyビルド時間を短縮できる
- 公式Amazon Linux 2023 AMIとカスタムAMIは、変数で切り替えられるようにしておくと検証しやすい
- 個人環境の `~/.ssh/config` をスクリプトで直接編集せず、確認用のSSH configブロックを出力する方式にした
- Terraform化する場合、Webサーバー、Security Group、ALBの依存関係をコード上で明確に表現する必要がある

## 注意事項

EC2インスタンスは起動中に課金対象となる。学習が終わったら停止または削除する。

WebサーバーはPublic IPを持たないため、直接SSH接続できない。接続には踏み台サーバー、VPN、またはAWS Systems Manager Session Managerなどが必要になる。

今回のスクリプトでは、`sample-sg-web` を新規作成する。同じスクリプトを複数回実行すると、同じGroup NameのSecurity Groupを作成しようとしてエラーになる可能性がある。

`~/.ssh/config` の内容は環境依存であり、既存設定を壊す可能性があるため、スクリプトでは自動変更せず、出力内容を確認して手動で反映する。

カスタムAMIはEBSスナップショットを保持するため、不要なAMIとスナップショットを残し続けると課金対象になる。学習用途では原則1世代のみ保持する。

## 削除時の注意

Webサーバーを削除する場合は、EC2インスタンスをterminateする。

```bash
aws ec2 terminate-instances \
  --profile learning \
  --region ap-northeast-1 \
  --instance-ids <Web01 Instance ID> <Web02 Instance ID>
```

Webサーバー用Security Groupは、EC2インスタンスに関連付けられている間は削除できない。EC2削除後にSecurity Groupを削除する。

```bash
aws ec2 delete-security-group \
  --profile learning \
  --region ap-northeast-1 \
  --group-name sample-sg-web
```
