# 05 Security

このディレクトリでは、AWS環境のセキュリティ確認、ネットワーク設定の影響調査、検知サービスの動作確認、変更手順の整理を行う。

目的は、GuardDuty、S3、VPC、Security Group、CloudWatch Logs、Lambdaなどを、単なるサービス名ではなく、実際の調査・設定確認・手順書作成の流れとして理解すること。

## 扱うテーマ

```text
AWSセキュリティ確認
ネットワーク設定の影響調査
設定変更前後の確認
検知結果の確認
手順書作成
```

## 学習方針

この章では、新しい大規模構成を作るより、既存のポートフォリオ環境をセキュリティ・運用目線で確認する。

特に意識する観点:

- 現状確認
- 影響範囲の確認
- 設定変更前後の差分確認
- ログ確認
- 作業後確認
- 切り戻し
- 手順書化

この章では、以下のように説明できる状態を目指す。

```text
個人AWS環境でGuardDuty、S3、VPC、Security Group、CloudWatch Logsなどを確認し、Finding確認、公開設定確認、通信影響調査、手順書作成の流れを整理している。
```

## ディレクトリ構成

```text
05-security/
  README.md
  scripts/
    01_guardduty_enable.sh
    02_guardduty_sample_findings.sh
    03_guardduty_cleanup.sh
    04_s3_security_check.sh
  notes/
    00_security_study_plan.md
    01_guardduty_reference.md
    02_s3_security_check.md
    03_vpc_security_group_impact.md
    04_lambda_basic.md
    05_change_procedure_example.md
```

## 学習ステップ

### 1. GuardDuty

GuardDutyは、AWSアカウント内の不審な挙動を検知する脅威検知サービス。

このポートフォリオでは、実際の攻撃テストは行わず、AWSが用意しているサンプルFindingを使う。

確認すること:

- GuardDuty Detectorとは何か
- Findingとは何か
- Severityの見方
- Finding Typeの見方
- 対象リソースの見方
- 検知後にどのログや設定を確認するか

確認後に説明できるようにすること:

```text
GuardDutyを有効化し、サンプルFindingを生成して、重要度、Finding Type、対象リソース、推奨対応を確認した。
実務ではFindingを起点に、対象リソース、CloudTrail、VPC Flow Logs、Security Group、IAM操作履歴などを確認して影響範囲を調査する流れになると理解している。
```

### 2. S3セキュリティ確認

このポートフォリオでは、Rails Active Storageの画像保存先としてS3を使っている。

確認すること:

- Block Public Access
- Bucket Policy
- ACL
- 暗号化
- Versioning
- IAM Roleからのアクセス

確認後に説明できるようにすること:

```text
S3については、Block Public Access、Bucket Policy、暗号化、Versioning、IAM Roleからのアクセス範囲を確認した。
意図しない外部公開がないか、必要最小限の権限になっているかを見ることが重要だと理解している。
```

### 3. VPC / Security Group / Route Table 影響調査

このポートフォリオの通信経路を使って、設定変更時の影響範囲を確認する。

主な通信:

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

確認すること:

- どのSecurity Groupが通信を許可しているか
- どのRoute Tableが経路を決めているか
- Public Subnet / Private Subnetの違い
- NAT Gatewayを止めると何が困るか
- ALBのTarget Groupがunhealthyになる原因

確認後に説明できるようにすること:

```text
Security Group変更時は、通信元、通信先、ポート、プロトコル、関連するALBやRDSなどを確認し、変更前の状態、作業後確認、切り戻し手順を整理する。
```

### 4. Lambda最小構成

LambdaはAWS環境の基本的な自動化・イベント処理を理解するため、最小構成で動作を確認する。

大きなアプリケーションを作る必要はない。

最初の目標:

- Lambda関数を1つ作る
- 実行Roleを理解する
- CloudWatch Logsにログが出ることを確認する
- EventBridgeや手動実行で起動する

確認後に説明できるようにすること:

```text
Lambdaについては、イベント駆動で処理を実行し、実行Roleの権限でAWSサービスへアクセスし、CloudWatch Logsへ実行ログを出す流れを確認した。
```

### 5. 手順書作成

実際に1本、変更手順書のサンプルを作る。

題材例:

```text
Security Group変更手順書
S3公開設定確認手順書
GuardDuty Finding確認手順書
```

手順書に入れる要素:

- 作業目的
- 作業対象
- 影響範囲
- 事前確認
- 作業手順
- 作業後確認
- 切り戻し手順
- 異常時の確認観点

確認後に説明できるようにすること:

```text
手順書作成では、作業手順だけでなく、事前確認、作業後確認、切り戻し手順、異常時の判断基準を入れることを意識している。
```

## 推奨実行順

週末の学習では、以下の順番で進める。

```text
1. GuardDutyの基本を読む
2. GuardDutyを有効化する
3. サンプルFindingを生成する
4. Finding詳細を確認する
5. S3セキュリティ設定を確認する
6. VPC / Security Groupの通信影響を整理する
7. Lambdaを最小構成で試す
8. 変更手順書サンプルを作る
```

費用を抑えるため、GuardDutyは学習後に削除または停止する。

## 注意点

- 実際の攻撃テストは行わない
- 意図的に危険なS3公開設定を作らない
- 本番相当のリソースに不要な設定変更をしない
- NAT Gateway、RDS、ElastiCacheなど課金が大きいリソースは必要な時だけ起動する
- GuardDutyは有効化している間、利用状況に応じて課金される
- 学習後に削除するもの、残すものを必ず分ける

## 到達目標

最終的には、以下の説明ができる状態を目指す。

```text
個人AWS環境でGuardDutyを有効化し、サンプルFindingを生成して、Findingの重要度、対象リソース、検知タイプを確認した。
また、S3の公開設定、Security Group、Route Table、CloudWatch Logsを確認し、設定変更時の影響調査と切り戻し手順を整理した。
```
