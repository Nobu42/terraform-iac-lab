# AWS Security Study Plan

## 目的

このメモは、AWS環境のセキュリティ確認、ネットワーク設定の影響調査、検知サービスの確認、変更手順書作成を段階的に学ぶための計画である。

対象は、既存のポートフォリオ環境で扱っている以下の構成とする。

- VPC
- Public Subnet / Private Subnet
- Security Group
- Route Table
- EC2
- ALB
- RDS
- S3
- CloudWatch Logs
- CloudWatch Alarm
- ElastiCache
- Route 53
- ACM
- Terraform
- Ansible

新しい大規模構成を作ることより、既存構成をセキュリティと運用の目線で説明できる状態にすることを優先する。

## 到達目標

最終的に以下を説明できる状態を目指す。

```text
個人AWS環境でGuardDutyを有効化し、サンプルFindingを生成して、Finding Type、Severity、対象リソース、推奨対応を確認した。
S3ではBlock Public Access、Bucket Policy、暗号化、Versioning、IAM Roleからのアクセス範囲を確認した。
VPCではSecurity Group、Route Table、NAT Gateway、ALB、RDS、ElastiCacheの通信経路を確認し、設定変更時の影響範囲を整理した。
また、設定変更時の事前確認、作業手順、作業後確認、切り戻し手順を手順書としてまとめた。
```

## 学習の全体像

```text
1. GuardDutyの基本確認
2. GuardDuty Detector有効化
3. サンプルFinding生成
4. Finding詳細確認
5. S3セキュリティ確認
6. VPC / Security Group / Route Table 影響調査
7. Lambda最小構成確認
8. CloudWatch Logs / EventBridge連携の確認
9. 変更手順書サンプル作成
10. 学習後のcleanup
```

## 1. GuardDutyの基本確認

GuardDutyは、AWSアカウント内の不審な挙動を検知する脅威検知サービスである。

主に以下のようなログやデータソースをもとに検知を行う。

- CloudTrail Management Events
- CloudTrail S3 Data Events
- VPC Flow Logs
- DNS Logs
- EKS Audit Logs
- Malware Protection関連情報

最初に覚える用語:

| 用語 | 意味 |
| :--- | :--- |
| Detector | GuardDutyをリージョンで有効化した単位 |
| Finding | GuardDutyが検知した結果 |
| Finding Type | 検知内容の種類 |
| Severity | 重要度 |
| Resource | 検知対象になったAWSリソース |
| Service | 検知に関する追加情報 |

最初に理解すること:

- GuardDutyはリージョン単位で有効化する
- 検知結果はFindingとして表示される
- Findingには重要度、対象リソース、検知タイプが含まれる
- 実際の攻撃テストを行わなくても、サンプルFindingを生成できる
- Finding確認後は、CloudTrail、VPC Flow Logs、Security Group、IAM、対象リソースの状態を確認する流れになる

## 2. GuardDuty有効化

GuardDutyを東京リージョンで有効化する。

確認コマンド:

```bash
aws guardduty list-detectors \
  --profile learning \
  --region ap-northeast-1
```

Detectorが存在しない場合は作成する。

```bash
aws guardduty create-detector \
  --profile learning \
  --region ap-northeast-1 \
  --enable
```

確認観点:

- Detector IDが作成されること
- `list-detectors` でDetector IDが取得できること
- 有効化したリージョンが `ap-northeast-1` であること

メモ:

- GuardDutyは有効化中に課金対象となる
- 学習後に削除する場合はDetector IDが必要になる
- 複数リージョンで有効化すると、リージョンごとに管理が必要になる

## 3. サンプルFinding生成

Detector IDを取得する。

```bash
DETECTOR_ID=$(aws guardduty list-detectors \
  --profile learning \
  --region ap-northeast-1 \
  --query 'DetectorIds[0]' \
  --output text)
```

サンプルFindingを生成する。

```bash
aws guardduty create-sample-findings \
  --profile learning \
  --region ap-northeast-1 \
  --detector-id "${DETECTOR_ID}"
```

Finding一覧を確認する。

```bash
aws guardduty list-findings \
  --profile learning \
  --region ap-northeast-1 \
  --detector-id "${DETECTOR_ID}"
```

確認観点:

- Finding IDが取得できること
- 複数のサンプルFindingが生成されること
- AWSマネジメントコンソールでもFindingが表示されること

## 4. Finding詳細確認

Finding IDを取得する。

```bash
FINDING_IDS=$(aws guardduty list-findings \
  --profile learning \
  --region ap-northeast-1 \
  --detector-id "${DETECTOR_ID}" \
  --query 'FindingIds[0:5]' \
  --output text)
```

Finding詳細を確認する。

```bash
aws guardduty get-findings \
  --profile learning \
  --region ap-northeast-1 \
  --detector-id "${DETECTOR_ID}" \
  --finding-ids ${FINDING_IDS} \
  --output json
```

見る項目:

| 項目 | 確認内容 |
| :--- | :--- |
| `type` | Finding Type |
| `severity` | 重要度 |
| `title` | 検知内容の概要 |
| `description` | 詳細説明 |
| `resource` | 対象リソース |
| `service.action` | 検知されたアクション |
| `service.eventFirstSeen` | 初回検知時刻 |
| `service.eventLastSeen` | 最終検知時刻 |
| `accountId` | 対象AWSアカウント |
| `region` | 対象リージョン |

調査時の考え方:

```text
1. 重要度を確認する
2. 対象リソースを確認する
3. Finding Typeを確認する
4. 関連するログを確認する
5. 通常運用か不審な挙動かを切り分ける
6. 必要な対応を決める
7. 対応内容と根拠を記録する
```

## 5. S3セキュリティ確認

対象はRails Active Storage用のS3バケットとする。

確認項目:

- Block Public Access
- Bucket Policy
- ACL
- 暗号化
- Versioning
- IAM Roleからのアクセス範囲

Block Public Access確認:

```bash
aws s3api get-public-access-block \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload
```

Bucket Policy確認:

```bash
aws s3api get-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload
```

暗号化確認:

```bash
aws s3api get-bucket-encryption \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload
```

Versioning確認:

```bash
aws s3api get-bucket-versioning \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload
```

確認観点:

- 意図しないPublic Accessがないこと
- Bucket Policyで `Principal: "*"` が使われていないこと
- 暗号化が設定されていること
- IAM Roleの権限が過剰でないか確認すること
- 学習環境で `AmazonS3FullAccess` を使っている場合、実務では最小権限へ寄せる必要があることを説明できること

## 6. VPC / Security Group / Route Table 影響調査

このポートフォリオの主要通信を整理する。

```text
User -> ALB : HTTPS 443
ALB -> Web EC2 : HTTP 3000
Bastion -> Web EC2 : SSH 22
Web EC2 -> RDS : MySQL 3306
Web EC2 -> ElastiCache : Redis 6379
Web EC2 -> S3 : HTTPS 443
Web EC2 -> SES : SMTP 587
Web EC2 -> Internet : NAT Gateway
```

確認するAWSリソース:

- Security Group
- Route Table
- Subnet
- NAT Gateway
- Internet Gateway
- ALB Listener
- Target Group
- RDS Security Group
- ElastiCache Security Group

Security Group確認:

```bash
aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=sample-sg-*"
```

Route Table確認:

```bash
aws ec2 describe-route-tables \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=tag:Name,Values=sample-rt-*"
```

ALB Target Health確認:

```bash
aws elbv2 describe-target-health \
  --profile learning \
  --region ap-northeast-1 \
  --target-group-arn <target-group-arn>
```

影響調査で整理すること:

| 変更対象 | 想定影響 |
| :--- | :--- |
| ALB SG inbound 443 | 利用者からHTTPS接続不可 |
| ALB SG egress 3000 | ALBからWeb EC2へ転送不可 |
| Web SG inbound 3000 | Target Group Health Check失敗 |
| Web SG egress 3306 | Web EC2からRDS接続不可 |
| RDS SG inbound 3306 | RailsアプリからDB接続不可 |
| Web SG egress 6379 | Web EC2からRedis接続不可 |
| Private Route Table default route | Private Subnetから外部接続不可 |
| NAT Gateway | パッケージ取得、外部API、SES SMTPなどに影響 |

## 7. Lambda最小構成確認

Lambdaは最小構成で確認する。

目的:

- Lambda関数の作成
- 実行Roleの理解
- CloudWatch Logs出力確認
- 手動実行またはEventBridge起動確認

最小構成の考え方:

```text
Lambda関数
  |
  | 実行Role
  v
CloudWatch Logs
```

確認すること:

- Lambdaはイベント駆動で実行される
- Lambdaは実行Roleの権限でAWS APIを呼び出す
- 実行ログはCloudWatch Logsへ出力される
- VPC内に配置する場合はSubnet、Security Group、NAT Gatewayが関係する

最初の学習では、VPC外LambdaでCloudWatch Logs出力だけを確認する。

## 8. 変更手順書サンプル作成

実際に1本、変更手順書を作る。

題材候補:

- Security Group変更手順書
- S3公開設定確認手順書
- GuardDuty Finding確認手順書

手順書に入れる項目:

```text
1. 作業目的
2. 作業対象
3. 前提条件
4. 影響範囲
5. 事前確認
6. 作業手順
7. 作業後確認
8. 切り戻し手順
9. 異常時の確認観点
10. 作業結果記録
```

重要な考え方:

- 作業手順だけでなく確認手順を書く
- 変更前の状態を記録する
- 正常性確認の基準を書く
- 切り戻し条件を書く
- 作業証跡を残す

## 9. cleanup

GuardDutyを学習後に削除する場合:

```bash
aws guardduty delete-detector \
  --profile learning \
  --region ap-northeast-1 \
  --detector-id "${DETECTOR_ID}"
```

確認:

```bash
aws guardduty list-detectors \
  --profile learning \
  --region ap-northeast-1
```

注意:

- GuardDutyを削除するとFindingも確認できなくなる
- 継続して学習する場合は、削除せず有効化したままでもよい
- 有効化したままにする場合は料金を確認する
- 作成したLambdaやIAM Roleも不要なら削除する

## 学習メモの作成方針

学習後、以下のメモを追加する。

```text
01_guardduty_reference.md
02_s3_security_check.md
03_vpc_security_group_impact.md
04_lambda_basic.md
05_change_procedure_example.md
```

各メモでは、以下を必ず整理する。

- 目的
- 実行コマンド
- 確認結果
- 見るべき項目
- つまずいた点
- 実務での使いどころ
