# Operation Design

## 目的

本書は、AWS学習環境を安全に構築、確認、運用、削除するための基本方針を定義する。

本環境は常時稼働ではなく、学習時のみAWSリソースを作成し、学習終了後に課金対象リソースを削除する運用を前提とする。

## 運用対象

- VPC
- Subnet
- Internet Gateway
- NAT Gateway
- Route Table
- Security Group
- EC2
- Application Load Balancer
- Target Group / Listener
- RDS for MySQL
- S3
- IAM Role / Instance Profile
- Route 53 Public Hosted Zone
- Route 53 Private Hosted Zone
- ACM Certificate
- SES
- ElastiCache for Redis
- CloudWatch
- Cost Explorer / AWS Budgets

## 運用方針

- AWS CLIとシェルスクリプトで構築手順を明確化する
- 学習時のみ課金対象リソースを作成する
- 学習終了後は削除スクリプトで課金対象リソースを削除する
- 削除後は確認スクリプトでリソースの残存を確認する
- 認証情報、秘密鍵、DBパスワード、SMTPパスワードはリポジトリに保存しない
- Security Groupは用途ごとに分離する
- Public SubnetとPrivate Subnetの役割を明確にする
- 実行前後にAWSアカウント、リージョン、プロファイルを確認する
- コスト確認を定期的に行う

## タグ管理

主要リソースには以下のタグを付与する。

| Key | Value |
| :--- | :--- |
| Name | リソース名 |
| Project | terraform-iac-lab |
| Environment | learning |

タグはリソース検索、コスト確認、削除対象の識別に利用する。

## 構築運用

### 構築前確認

構築前に以下を確認する。

- AWS CLIのプロファイルが `learning` であること
- リージョンが `ap-northeast-1` であること
- LocalStack用の環境変数やaliasが残っていないこと
- 予算アラートが設定されていること
- 前回の学習リソースが残っていないこと

確認例:

```bash
aws sts get-caller-identity --profile learning --output table
./check_cleanup.sh
```

### 構築後確認

構築後は `check_setup.sh` を実行し、主要リソースの状態を確認する。

```bash
./check_setup.sh
```

確認観点:

- VPC、Subnet、Route Tableが作成されていること
- NAT Gatewayが `available` であること
- EC2が `running` であること
- ALBが `active` であること
- Target GroupのTarget Healthが `healthy` であること
- RDSが `available` であること
- S3バケットが存在すること
- Public DNS / Private DNS が作成されていること
- ACM証明書が `ISSUED` であること
- SES Identityが認証済みであること
- ElastiCache Replication Groupが `available` であること

## 削除運用

学習終了後は `cleanup_all.sh` を実行する。

```bash
./cleanup_all.sh
```

削除後は `check_cleanup.sh` を実行し、課金対象リソースが残っていないことを確認する。

```bash
./check_cleanup.sh
```

削除対象:

- VPC
- Subnet
- Internet Gateway
- NAT Gateway
- Elastic IP
- Route Table
- Security Group
- EC2
- ALB
- Target Group
- RDS
- S3バケット
- Route 53 Private Hosted Zone
- Public DNS一時レコード
- SES受信用S3
- SES Receipt Rule / Receipt Rule Set
- SES受信用MXレコード
- ElastiCache Replication Group
- ElastiCache Subnet Group

削除せず残すリソース:

- ドメイン登録
- Route 53 Public Hosted Zone
- ACM証明書
- ACM DNS検証用CNAME
- SES Domain Identity
- SES DKIM / SPF / DMARC レコード
- SES SMTP用IAMユーザー

## 監視設計

CloudWatchを利用して、以下の項目を監視対象とする。

### EC2

- CPUUtilization
- StatusCheckFailed
- NetworkIn / NetworkOut
- Disk使用率
- メモリ使用率

Disk使用率とメモリ使用率はCloudWatch Agentの導入後に取得する。

### ALB / Target Group

- HTTPCode_ELB_5XX_Count
- HTTPCode_Target_5XX_Count
- TargetResponseTime
- HealthyHostCount
- UnHealthyHostCount
- RequestCount

### RDS

- CPUUtilization
- FreeStorageSpace
- DatabaseConnections
- FreeableMemory
- ReadLatency / WriteLatency

### NAT Gateway

- BytesOutToDestination
- BytesInFromSource
- ErrorPortAllocation
- PacketsDropCount

### ElastiCache

- CPUUtilization
- DatabaseMemoryUsagePercentage
- CurrConnections
- CacheHits
- CacheMisses
- ReplicationLag

### SES

- Send
- Bounce
- Complaint
- Reject
- Delivery

## アラーム設計

学習環境では、まず以下のCloudWatch Alarmを作成する。

| 対象 | メトリクス | 条件例 | 目的 |
| :--- | :--- | :--- | :--- |
| EC2 | StatusCheckFailed | 1以上 | インスタンス異常検知 |
| ALB | UnHealthyHostCount | 1以上 | Webサーバー異常検知 |
| ALB | HTTPCode_Target_5XX_Count | しきい値超過 | アプリケーション異常検知 |
| RDS | CPUUtilization | 80%以上 | DB負荷検知 |
| RDS | FreeStorageSpace | 低下 | DB容量不足検知 |
| ElastiCache | CPUUtilization | 80%以上 | Redis負荷検知 |
| SES | Bounce / Complaint | 増加 | メール品質低下検知 |

通知先はSNS Topicを利用する想定とする。

## ログ設計

今後、以下のログをCloudWatch LogsまたはS3で管理する。

- EC2 OSログ
- アプリケーションログ
- ALB Access Logs
- VPC Flow Logs
- RDSログ
- SES受信メール
- デプロイログ

学習初期段階では、EC2上のログ確認から開始し、CloudWatch Agent導入後にCloudWatch Logsへ集約する。

## バックアップ設計

### RDS

現在の学習環境では、コストを抑えるためRDSのバックアップ保持期間は `0` としている。

今後、運用設計の検証時に以下を追加する。

- 自動バックアップ
- 手動スナップショット
- 世代管理
- リストア手順
- Multi-AZ構成

### S3

S3は学習用データを保存する用途とし、学習終了時に削除する。

必要に応じて以下を検討する。

- バージョニング
- ライフサイクルルール
- 暗号化
- アクセスログ

### EC2 AMI

日次でAWSリソースを削除し、翌日に再構築する運用では、Rubyのソースビルドに時間がかかる。

そのため、Ansibleで以下を導入した直後のWeb EC2をベースAMIとして保存し、次回以降のWeb EC2作成時間を短縮する。

AMIに含めるもの:

- Amazon Linux 2023
- 共通パッケージ
- deployユーザー
- nginx
- rbenv
- Ruby 3.3.6
- Bundler

AMIに含めないもの:

- Railsアプリケーション本体
- DBパスワード
- SES SMTPパスワード
- secret_key_base
- 投稿画像
- 一時ログ

作成済みAMI:

```text
AMI ID: ami-00f86224c38cc3b8c
Name  : web-base-ruby336-rails72-20260505-102118
```

AMIは `20_create_web_base_ami.sh` で作成する。

```bash
cd 01-aws-cli/scripts
./20_create_web_base_ami.sh
```

運用上の注意:

- AMIは裏側でEBSスナップショットを保持するため、不要なAMIとスナップショットは削除する
- 古いAMIを複数世代残し続けると、スナップショット保存料金が増える
- 学習用途では原則1世代のみ保持する
- OSやRubyの更新が必要になった場合は、新しいAMIを作成し直す
- アプリケーションや秘密情報はAMIへ焼き込まず、Ansibleや環境変数で後から設定する

## セキュリティ運用

- rootユーザーは通常利用しない
- IAMユーザーには必要な権限のみ付与する
- MFAを有効化する
- Security Groupは用途ごとに分離する
- BastionへのSSHは自分のグローバルIPに制限する
- WebサーバーとRDSはPrivate Subnetに配置する
- DBパスワードは環境変数で渡す
- SMTP Username / Passwordは環境変数で渡す
- `.pem` ファイルや認証情報はGit管理しない
- SESの送信品質を維持するため、BounceとComplaintを確認する

## コスト管理

### 確認方法

Cost Explorerを利用し、月初から現在までの利用料金を確認する。

```bash
./check_cost.sh
```

### 主な課金注意リソース

- NAT Gateway
- ALB
- RDS
- ElastiCache
- EC2
- Elastic IP
- Route 53 Hosted Zone
- ドメイン登録
- S3
- CloudWatch Logs
- CloudWatch Alarm

### AWS Budgets

AWS Budgetsで予算を設定し、一定金額を超えた場合に通知を受け取る。

現在は学習用として月額予算を設定し、想定外の課金を早期に検知する。

## 障害対応

### ALB Targetがunhealthy

確認項目:

- Webサーバーでアプリケーションが起動しているか
- `python3 -m http.server 3000` またはRailsアプリが3000番で待ち受けているか
- `sample-sg-web` が `sample-sg-elb` からの3000/tcpを許可しているか
- Target Groupのヘルスチェックパスが正しいか

### EC2にSSH接続できない

確認項目:

- Bastionが起動しているか
- Security Groupで自分のグローバルIPが許可されているか
- SSH秘密鍵の権限が正しいか
- `~/.ssh/config` のHostNameが最新のPublic DNSまたはIPになっているか
- Private EC2へ接続する場合、ProxyJump設定が正しいか

### RDSに接続できない

確認項目:

- RDSが `available` であるか
- Webサーバーから接続しているか
- `sample-sg-db` が `sample-sg-web` からの3306/tcpを許可しているか
- 接続先が `db.home` または最新のRDS Endpointになっているか
- ユーザー名とパスワードが正しいか

### ElastiCacheに接続できない

確認項目:

- Replication Groupが `available` であるか
- Webサーバーから接続しているか
- `sample-sg-elasticache` が `sample-sg-web` からの6379/tcpを許可しているか
- Cluster Mode Enabledに対応したRedisクライアントを利用しているか
- 接続先がConfiguration Endpointになっているか

### SESでメール送信できない

確認項目:

- SES Domain Identityが認証済みか
- DKIMが `SUCCESS` になっているか
- SES SMTP Username / Passwordが正しいか
- Fromアドレスが検証済みドメイン配下か
- Sandbox環境の場合、送信先メールアドレスも検証済みか
- Production Accessが有効化されているか

### SESでメール受信できない

確認項目:

- MXレコードが正しいか
- Receipt Rule SetがActiveになっているか
- Receipt RuleがEnabledになっているか
- 受信アドレスがRuleのRecipientに一致しているか
- S3 Bucket PolicyでSESからのPutObjectを許可しているか

### NAT Gateway経由で外部通信できない

確認項目:

- NAT Gatewayが `available` であるか
- Private Route TableのデフォルトルートがNAT Gatewayを向いているか
- NAT GatewayがPublic Subnetに配置されているか
- Public Route TableがInternet Gatewayを向いているか

## 定期作業

### 学習開始時

- `aws sts get-caller-identity` で作業アカウントを確認する
- `check_cleanup.sh` で前回リソースの残存を確認する
- 必要な構築スクリプトを実行する
- `check_setup.sh` で構築状態を確認する

### 学習終了時

- `cleanup_all.sh` で課金対象リソースを削除する
- `check_cleanup.sh` で削除状態を確認する
- `check_cost.sh` で利用料金を確認する
- Gitに変更をコミットする

### 週次

- AWS BudgetsとCost Explorerを確認する
- IAMユーザーと不要なアクセスキーを確認する
- Security Groupの公開範囲を確認する
- GitHubに秘密情報が含まれていないか確認する

### 月次

- AWS利用料金を確認する
- Route 53、SES、ACM、IAMなど残すリソースを確認する
- ドキュメントと構成図を最新化する
- Terraform化、監視設定、デプロイ手順の進捗を確認する
