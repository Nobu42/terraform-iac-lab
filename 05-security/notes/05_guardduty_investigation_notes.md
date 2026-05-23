# GuardDuty Investigation Notes

## 目的

このメモは、GuardDutyのFindingを確認した後、どの項目を読み、どのAWSログや設定に進むかを整理するための調査メモである。

GuardDutyの有効化やサンプルFinding生成だけで終わらせず、以下を説明できる状態にする。

```text
GuardDuty FindingをSeverity、Type、ResourceTypeごとに確認し、対象リソースごとの調査観点を整理した。
IAM AccessKey、S3、EC2、RDS、LambdaのFindingを確認し、CloudTrail、VPC Flow Logs、CloudWatch Logs、Security Group、Bucket Policyなど、次に確認すべき証跡を整理した。
```

## 使用したスクリプト

```text
05-security/scripts/
  01_guardduty_enable.sh
  02_create_sample_findings.sh
  03_get_findings_detail.sh
  04_get_findings_by_type.sh
```

実行順:

```bash
cd /Users/nobu/terraform-iac-lab/05-security/scripts

./01_guardduty_enable.sh
./02_create_sample_findings.sh
./03_get_findings_detail.sh
./04_get_findings_by_type.sh AccessKey
./04_get_findings_by_type.sh S3Bucket
./04_get_findings_by_type.sh Instance
./04_get_findings_by_type.sh RDSDBInstance
./04_get_findings_by_type.sh Lambda
```

## GuardDutyで最初に見る項目

GuardDuty Findingでは、最初に以下を見る。

| 項目 | 見る内容 |
| :--- | :--- |
| `Severity` | 重要度。数値が高いほど優先度が高い |
| `Type` | 検知内容の分類 |
| `Title` | 検知内容の概要 |
| `Description` | 詳細説明 |
| `Resource.ResourceType` | 対象リソースの種類 |
| `Resource` | 対象リソースの詳細 |
| `Service.Action` | 検知されたアクション |
| `Service.EventFirstSeen` | 初回検知時刻 |
| `Service.EventLastSeen` | 最終検知時刻 |

調査の基本順序:

```text
1. Severityを確認する
2. Typeを確認する
3. ResourceTypeを確認する
4. 対象リソースIDまたは対象ユーザーを確認する
5. Service.Actionを確認する
6. FirstSeen / LastSeenで時間帯を確認する
7. CloudTrail、VPC Flow Logs、CloudWatch Logsなど関連ログへ進む
8. 通常運用か不審挙動かを切り分ける
9. 必要な封じ込め、設定変更、切り戻し、再発防止を整理する
```

## Severityの見方

GuardDutyのSeverityは数値で表示される。

| Severity | 目安 | 対応方針 |
| :--- | :--- | :--- |
| 8.0 - 10.0 | High | 優先対応。認証情報侵害、外部通信、データ持ち出し、侵害疑いを優先確認 |
| 4.0 - 7.9 | Medium | 早めに確認。異常なAPI、Tor、通常と異なる通信やログインを確認 |
| 1.0 - 3.9 | Low | 状況確認。設定不備、軽微な不審挙動、補助的なシグナルを確認 |

今回確認したサンプルでは、`Severity 9.0` のAttackSequence、`Severity 8.0` のS3、RDS、EC2系Finding、`Severity 5.0` のLambdaやAccessKey系Finding、`Severity 2.0` のRuntime系Findingを確認した。

## Finding Typeの読み方

Finding Typeは、概ね以下の構造で読む。

```text
分類:対象/検知内容
```

例:

```text
Exfiltration:S3/AnomalousBehavior
UnauthorizedAccess:IAMUser/TorIPCaller
CredentialAccess:RDS/AnomalousBehavior.SuccessfulLogin
Backdoor:Runtime/C&CActivity.B!DNS
Trojan:Lambda/DropPoint
```

読み方:

| Type例 | 読み方 |
| :--- | :--- |
| `Exfiltration:S3/AnomalousBehavior` | S3で通常と異なるデータ持ち出し系の挙動 |
| `UnauthorizedAccess:IAMUser/TorIPCaller` | IAMユーザーのAPI操作がTor出口ノードから実行された疑い |
| `CredentialAccess:RDS/AnomalousBehavior.SuccessfulLogin` | RDSへ通常と異なるログイン成功があった疑い |
| `Backdoor:Runtime/C&CActivity.B!DNS` | C2関連ドメインへのDNS問い合わせ疑い |
| `Trojan:Lambda/DropPoint` | LambdaがDrop Pointと通信した疑い |

## ResourceType別の調査観点

### AccessKey

確認した代表Finding:

| Severity | Type | 意味 |
| :--- | :--- | :--- |
| 5.0 | `InitialAccess:IAMUser/AnomalousBehavior` | IAMユーザーが通常と異なるAPIを実行 |
| 8.0 | `Policy:S3/BucketAnonymousAccessGranted` | S3 Bucketに匿名アクセスが許可された疑い |
| 2.0 | `Policy:IAMUser/RootCredentialUsage` | root認証情報でAPIが実行された |
| 5.0 | `UnauthorizedAccess:IAMUser/TorIPCaller` | Tor出口ノードからAPIが実行された疑い |

最初に見る項目:

```text
Resource.AccessKeyDetails.AccessKeyId
Resource.AccessKeyDetails.UserName
Resource.AccessKeyDetails.UserType
Resource.AccessKeyDetails.PrincipalId
Service.Action.AwsApiCallAction.Api
Service.Action.AwsApiCallAction.RemoteIpDetails
```

調査観点:

- 対象Access Key IDを確認する
- 対象IAMユーザー、Role、Principal IDを確認する
- CloudTrailで該当時間帯のAPI操作を確認する
- 実行API、接続元IP、リージョン、UserAgentを確認する
- 普段使わないリージョンからの操作がないか確認する
- `iam:CreateRole`、`iam:AttachRolePolicy`、`cloudtrail:DeleteTrail`、`s3:GetObject` など危険度の高いAPIを確認する
- 必要に応じてAccess Keyを無効化する
- IAM Policyを一時的に絞る
- 認証情報をローテーションする
- CloudTrailの証跡を保全する

実務での説明例:

```text
AccessKey系Findingでは、まず対象Access KeyとIAMユーザーを特定し、CloudTrailで該当時間帯のAPI操作を確認する。
API名、接続元IP、リージョン、UserAgentを確認し、通常運用と異なる操作かを切り分ける。
認証情報漏えいの疑いが強い場合は、Access Key無効化、権限剥奪、認証情報ローテーションを優先する。
```

### S3Bucket

確認した代表Finding:

| Severity | Type | 意味 |
| :--- | :--- | :--- |
| 8.0 | `Exfiltration:S3/AnomalousBehavior` | S3 APIが通常と異なる形で実行された |
| 8.0 | `UnauthorizedAccess:S3/TorIPCaller` | Tor出口ノードからS3 APIが実行された疑い |

最初に見る項目:

```text
Resource.S3BucketDetails[].Name
Resource.S3BucketDetails[].Arn
Resource.S3BucketDetails[].PublicAccess
Resource.AccessKeyDetails
Service.Action.AwsApiCallAction.Api
Service.Action.AwsApiCallAction.RemoteIpDetails
```

調査観点:

- 対象Bucket名を確認する
- BucketがPublicになっていないか確認する
- Block Public Accessを確認する
- Bucket Policyを確認する
- ACLを確認する
- 暗号化設定を確認する
- Versioningを確認する
- CloudTrail S3 Data Eventsで操作主体とAPIを確認する
- `GetObject`、`ListBucket`、`PutBucketPolicy`、`PutBucketAcl` などを確認する
- IAM User、Role、Access Keyの権限を確認する
- 必要に応じてPublic Accessを遮断する
- Bucket Policyを修正する
- Access Keyを無効化またはローテーションする

確認コマンド例:

```bash
aws s3api get-public-access-block \
  --profile learning \
  --region ap-northeast-1 \
  --bucket <bucket-name>

aws s3api get-bucket-policy \
  --profile learning \
  --region ap-northeast-1 \
  --bucket <bucket-name>

aws s3api get-bucket-encryption \
  --profile learning \
  --region ap-northeast-1 \
  --bucket <bucket-name>

aws s3api get-bucket-versioning \
  --profile learning \
  --region ap-northeast-1 \
  --bucket <bucket-name>
```

実務での説明例:

```text
S3系Findingでは、対象Bucket、Public Access、Bucket Policy、ACL、暗号化、Versioningを確認する。
あわせてCloudTrail S3 Data Eventsで、誰がどのAPIをどの接続元から実行したかを確認する。
意図しない公開や不審なデータ取得が疑われる場合は、Public Access遮断、Policy修正、認証情報ローテーションを行う。
```

### Instance

確認した代表Finding:

| Severity | Type | 意味 |
| :--- | :--- | :--- |
| 5.0 | `Behavior:EC2/TrafficVolumeUnusual` | EC2から通常より多い通信量 |
| 8.0 | `Backdoor:Runtime/C&CActivity.B!DNS` | C2関連ドメインへのDNS問い合わせ疑い |
| 8.0 | `Execution:EC2/MaliciousFile` | 悪性ファイル検知 |
| 5.0 | `DefenseEvasion:EC2/UnusualDNSResolver` | 通常と異なるDNS Resolver利用 |
| 5.0 | `Impact:EC2/AbusedDomainRequest.Reputation` | 既知の悪用ドメインとの通信 |
| 2.0 | `Persistence:Runtime/SuspiciousCommand` | 不審コマンド実行 |
| 2.0 | `PrivilegeEscalation:Runtime/ElevationToRoot` | root権限昇格疑い |

最初に見る項目:

```text
Resource.InstanceDetails.InstanceId
Resource.InstanceDetails.InstanceState
Resource.InstanceDetails.NetworkInterfaces[].PublicIp
Resource.InstanceDetails.NetworkInterfaces[].PrivateIpAddress
Resource.InstanceDetails.NetworkInterfaces[].SecurityGroups
Resource.InstanceDetails.NetworkInterfaces[].SubnetId
Resource.InstanceDetails.NetworkInterfaces[].VpcId
Service.Action.NetworkConnectionAction
Service.Action.DnsRequestAction
```

調査観点:

- 対象Instance IDを確認する
- Security Groupを確認する
- Subnetを確認する
- Route Tableを確認する
- Public IP有無を確認する
- VPC Flow Logsで通信元、通信先、port、actionを確認する
- CloudWatch LogsでOSログ、アプリログを確認する
- SSHログ、sudoログ、cron、プロセスを確認する
- 不審なOutbound通信がないか確認する
- C2通信疑いではDNS問い合わせ先を確認する
- 必要に応じてSecurity Groupで通信制限する
- Instanceを隔離する
- AMIまたはSnapshotを取得する
- ログを保全する

確認コマンド例:

```bash
aws ec2 describe-instances \
  --profile learning \
  --region ap-northeast-1 \
  --instance-ids <instance-id>

aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --group-ids <security-group-id>

aws ec2 describe-route-tables \
  --profile learning \
  --region ap-northeast-1 \
  --filters "Name=association.subnet-id,Values=<subnet-id>"
```

実務での説明例:

```text
EC2系Findingでは、対象Instance、Security Group、Subnet、Route Table、Public IPの有無を確認する。
通信系FindingであればVPC Flow Logs、DNS系FindingであればDNS問い合わせ、Runtime系FindingであればOSログやプロセスを確認する。
侵害疑いが強い場合は、通信制限、Instance隔離、AMI取得、ログ保全を優先する。
```

### RDSDBInstance

確認した代表Finding:

| Severity | Type | 意味 |
| :--- | :--- | :--- |
| 8.0 | `CredentialAccess:RDS/AnomalousBehavior.SuccessfulLogin` | RDSへ通常と異なるログイン成功 |
| 5.0 | `CredentialAccess:RDS/MaliciousIPCaller.FailedLogin` | 悪性IPからRDSログイン失敗 |

最初に見る項目:

```text
Resource.RdsDbInstanceDetails.DbInstanceIdentifier
Resource.RdsDbInstanceDetails.Engine
Resource.RdsDbUserDetails.User
Resource.RdsDbUserDetails.Database
Resource.RdsDbUserDetails.AuthMethod
Service.Action.RdsLoginAttemptAction.RemoteIpDetails
```

調査観点:

- 対象DB Instance Identifierを確認する
- DBユーザーを確認する
- 接続元IPを確認する
- ログイン成功か失敗かを確認する
- RDSのSecurity Groupを確認する
- DB Subnet Groupを確認する
- RDSログを確認する
- CloudTrailでRDS設定変更がないか確認する
- アプリケーション側の接続元と一致するか確認する
- 必要に応じてDBパスワードを変更する
- Security Groupを制限する
- 認証情報をローテーションする

確認コマンド例:

```bash
aws rds describe-db-instances \
  --profile learning \
  --region ap-northeast-1 \
  --db-instance-identifier <db-instance-identifier>

aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --group-ids <rds-security-group-id>
```

実務での説明例:

```text
RDS系Findingでは、対象DB、DBユーザー、接続元IP、ログイン成否を確認する。
Security GroupとSubnet Groupで接続経路を確認し、RDSログとCloudTrailを突き合わせる。
不審なログイン成功であれば、パスワード変更、Security Group制限、認証情報ローテーションを優先する。
```

### Lambda

確認した代表Finding:

| Severity | Type | 意味 |
| :--- | :--- | :--- |
| 5.0 | `Trojan:Lambda/DropPoint` | LambdaがDrop Pointと通信した疑い |

Drop Pointは、マルウェアが盗んだ認証情報やデータを送信する外部ホストを指す。

最初に見る項目:

```text
Resource.LambdaDetails.FunctionName
Resource.LambdaDetails.FunctionArn
Resource.LambdaDetails.Role
Resource.LambdaDetails.VpcConfig
Service.Action.NetworkConnectionAction.RemoteIpDetails
Service.Action.NetworkConnectionAction.RemotePortDetails
```

調査観点:

- 対象Function名を確認する
- Function ARNを確認する
- 実行Roleを確認する
- VPC設定を確認する
- Security Groupを確認する
- Subnetを確認する
- CloudWatch Logsで該当時間帯の実行ログを確認する
- 外部通信先IPとPortを確認する
- 環境変数に認証情報がないか確認する
- Layerやデプロイ履歴を確認する
- 実行Roleの権限が過剰でないか確認する
- 必要に応じて関数停止、Role権限修正、環境変数ローテーションを行う

確認コマンド例:

```bash
aws lambda get-function \
  --profile learning \
  --region ap-northeast-1 \
  --function-name <function-name>

aws logs describe-log-groups \
  --profile learning \
  --region ap-northeast-1 \
  --log-group-name-prefix /aws/lambda/<function-name>
```

実務での説明例:

```text
Lambda系Findingでは、対象Function、実行Role、VPC設定、Security Group、CloudWatch Logsを確認する。
外部通信先と実行Roleの権限を確認し、必要に応じて関数停止、Role権限修正、環境変数や認証情報のローテーションを行う。
```

### AttackSequence

確認した代表Finding:

| Severity | Type | 意味 |
| :--- | :--- | :--- |
| 9.0 | `AttackSequence:EKS/CompromisedCluster` | 複数シグナルからEKS侵害疑いを検知 |
| 9.0 | `AttackSequence:IAM/CompromisedCredentials` | 複数シグナルからIAM認証情報侵害疑いを検知 |

AttackSequenceは、単発のAPIや通信ではなく、複数の不審な挙動をまとめて侵害可能性として検知するFindingである。

確認したサンプルでは、以下のような情報が含まれていた。

```text
MITRE tactics
MITRE techniques
Suspicious DNS query
Cryptomining domain
xmrig process
Sensitive API calls
Tor Exit Node
```

調査観点:

- AttackSequenceの対象を確認する
- IAMなのかEKSなのかを確認する
- 含まれるシグナルを分解する
- CloudTrailで該当APIを確認する
- EKSの場合はEKS Audit Logsを確認する
- EC2やContainerが関係する場合はRuntime系ログを確認する
- DNSや通信が関係する場合はVPC Flow Logsを確認する
- Sensitive APIが含まれる場合はIAM変更履歴を確認する
- 侵害疑いが強い場合は、認証情報無効化、権限見直し、対象リソース隔離を優先する

実務での説明例:

```text
AttackSequenceは、単一のイベントではなく複数の不審な操作や通信をつなげて侵害疑いとして検知するFindingである。
まず含まれるシグナルを分解し、CloudTrail、EKS Audit Logs、VPC Flow Logs、対象リソースの状態を確認する。
重要度が高いため、確認と並行して封じ込め方針を検討する。
```

## 調査時に使う主なログ

| ログ | 主な用途 |
| :--- | :--- |
| CloudTrail Management Events | IAM、S3、EC2、RDSなどのAPI操作確認 |
| CloudTrail S3 Data Events | S3 Object操作確認 |
| VPC Flow Logs | 通信元、通信先、port、ACCEPT/REJECT確認 |
| CloudWatch Logs | EC2、アプリ、Lambdaのログ確認 |
| RDS Logs | DBログイン、SQL、エラー確認 |
| EKS Audit Logs | Kubernetes API操作確認 |

GuardDutyは「検知結果」を出すサービスであり、詳細調査では各種ログと設定情報を突き合わせる。

## 影響調査の考え方

設定変更前に整理すること:

```text
1. 変更対象
2. 変更理由
3. 影響する通信
4. 影響するAWSリソース
5. 正常性確認方法
6. 切り戻し方法
7. 作業前状態の記録
8. 作業後状態の記録
```

例: Security Group変更時

| 確認項目 | 内容 |
| :--- | :--- |
| 通信元 | ALB、Bastion、Web EC2、外部IPなど |
| 通信先 | Web EC2、RDS、ElastiCacheなど |
| Port | 22、80、443、3000、3306、6379など |
| Protocol | TCP、UDPなど |
| 関連リソース | Subnet、Route Table、NAT Gateway、Target Groupなど |
| 正常性確認 | curl、target-health、アプリログ、DB接続確認 |
| 切り戻し | 元のSecurity Group Ruleへ戻す |

## Finding確認後の初動テンプレート

```text
1. Finding ID:
2. Severity:
3. Type:
4. ResourceType:
5. 対象リソース:
6. FirstSeen:
7. LastSeen:
8. Service.Action:
9. 影響範囲:
10. 確認したログ:
11. 判断:
12. 実施した対応:
13. 切り戻し要否:
14. 再発防止:
```

判断の書き方例:

```text
サンプルFindingのため実際の侵害ではない。
ただし実務では、対象IAMユーザー、Access Key、CloudTrail、接続元IP、実行APIを確認し、通常運用と異なる場合は認証情報無効化や権限剥奪を検討する。
```

## 今回の学習で説明できること

```text
GuardDutyを有効化し、サンプルFindingを生成した。
FindingをResourceType別に絞り込み、AccessKey、S3Bucket、Instance、RDSDBInstance、Lambdaの代表的なFindingを確認した。
Severity、Type、Title、ResourceTypeを一覧化し、対象リソースごとの調査観点を整理した。
Finding単体で判断せず、CloudTrail、VPC Flow Logs、CloudWatch Logs、RDSログ、Security Group、Bucket Policyなどの証跡と突き合わせる必要があると整理した。
```

## 次にやること

次は、実リソースに対して以下を確認する。

```text
S3:
  - Block Public Access
  - Bucket Policy
  - 暗号化
  - Versioning

VPC / Security Group:
  - ALB -> Web EC2
  - Bastion -> Web EC2
  - Web EC2 -> RDS
  - Web EC2 -> ElastiCache
  - Web EC2 -> NAT Gateway

CloudWatch:
  - nginxログ
  - Pumaログ
  - CloudWatch Alarm

手順書:
  - GuardDuty Finding確認手順
  - Security Group変更手順
  - S3公開設定確認手順
```

## cleanup

GuardDutyを残さない場合はDetectorを削除する。

```bash
DETECTOR_ID=$(aws guardduty list-detectors \
  --profile learning \
  --region ap-northeast-1 \
  --query 'DetectorIds[0]' \
  --output text)

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

- GuardDutyは有効化中に課金対象となる
- サンプルFindingは実際の侵害ではない
- Detectorを削除するとFindingも確認できなくなる
- 学習を継続する場合は削除前にメモを残す
