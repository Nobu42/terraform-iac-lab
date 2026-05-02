# 11 S3 Setup

## 目的

AWS CLIでS3バケットを作成し、Webサーバー用EC2からS3へファイルをアップロードできるようにする。

EC2上にアクセスキーを配置せず、IAMロールをEC2に関連付けてS3へアクセスする構成にする。Railsアプリケーションで画像などのアップロード先としてS3を利用する前段の確認を行う。

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース:
  - S3 Bucket
  - IAM Role
  - IAM Instance Profile
  - EC2 IAM Role Association
- 前提:
  - `sample-ec2-web01` が起動済みであること
  - `sample-ec2-web02` が起動済みであること
  - WebサーバーへSSH接続できること

## 設計値

| 項目 | 値 |
| :--- | :--- |
| S3バケット名 | nobu-terraform-iac-lab-upload |
| リージョン | ap-northeast-1 |
| パブリックアクセス | 全てブロック |
| ACL | 無効 |
| デフォルト暗号化 | 明示的な設定なし |
| IAMロール名 | sample-role-web |
| ロール説明 | upload images |
| 信頼されたエンティティ | EC2 |
| 許可ポリシー | AmazonS3FullAccess |
| 適用先EC2 | sample-ec2-web01, sample-ec2-web02 |

## IAMロール設計

| 項目 | 内容 |
| :--- | :--- |
| Role | sample-role-web |
| Instance Profile | sample-role-web |
| Principal | ec2.amazonaws.com |
| Policy | AmazonS3FullAccess |

EC2からS3へアクセスするため、IAMロールを作成し、Instance Profile経由でWebサーバーに関連付ける。

## スクリプト

- [11_s3_setup.sh](../scripts/11_s3_setup.sh)

## 実行コマンド

```bash
./11_s3_setup.sh
```

## 確認コマンド

S3バケットのパブリックアクセスブロック設定を確認する。

```bash
aws s3api get-public-access-block \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --output table
```

S3バケットのACL無効化設定を確認する。

```bash
aws s3api get-bucket-ownership-controls \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload \
  --output table
```

EC2にIAM Instance Profileが関連付いているか確認する。

```bash
aws ec2 describe-iam-instance-profile-associations \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=instance-id,Values=<Web01 Instance ID>,<Web02 Instance ID> \
  --query 'IamInstanceProfileAssociations[*].{InstanceId:InstanceId,State:State,ProfileArn:IamInstanceProfile.Arn}' \
  --output table
```

IAMロールにポリシーが付与されているか確認する。

```bash
aws iam list-attached-role-policies \
  --profile learning \
  --role-name sample-role-web \
  --output table
```

## EC2からS3へのアップロード確認

WebサーバーへSSH接続し、S3へファイルをアップロードできることを確認した。

Web01での確認例:

```bash
ssh web01
echo "upload test from web01" > test01.txt
aws s3 cp test01.txt s3://nobu-terraform-iac-lab-upload
```

Web02での確認例:

```bash
ssh web02
echo "upload test from web02" > test02.txt
aws s3 cp test02.txt s3://nobu-terraform-iac-lab-upload
```

S3バケット内のファイル一覧を確認する。

```bash
aws s3 ls s3://nobu-terraform-iac-lab-upload
```

確認結果:

```text
test01.txt
test02.txt
```

EC2上にアクセスキーを配置せず、IAMロール経由でS3へアクセスできることを確認した。

## 実AWSでの実行結果

S3バケットを作成し、Webサーバー2台にIAMロールを適用した。

| 項目 | 結果 |
| :--- | :--- |
| S3 Bucket | 作成済み |
| Public Access Block | 有効 |
| ACL | 無効 |
| IAM Role | sample-role-web |
| Instance Profile | sample-role-web |
| Web01からS3アップロード | 成功 |
| Web02からS3アップロード | 成功 |

## 学んだこと

- S3バケット名は全AWSアカウントで一意である必要がある
- S3のパブリックアクセスは明示的にブロックできる
- `BucketOwnerEnforced` を設定するとACLを使わない運用にできる
- EC2からAWSサービスへアクセスする場合、アクセスキーを置くのではなくIAMロールを使う
- EC2にIAMロールを付けるには、Instance Profileが必要
- IAMロールの信頼ポリシーで `ec2.amazonaws.com` を指定すると、EC2がそのロールを引き受けられる
- IAMロールの反映には少し時間がかかることがある
- JMESPathの関数はAWS CLI環境によって利用できない場合があるため、確認用queryはシンプルにした

## 注意事項

今回のスクリプトでは、学習用に `AmazonS3FullAccess` をIAMロールへ付与している。

実運用では、対象バケットだけに絞った最小権限ポリシーを作成する。

例:

```text
s3:ListBucket
s3:GetObject
s3:PutObject
s3:DeleteObject
```

対象:

```text
arn:aws:s3:::nobu-terraform-iac-lab-upload
arn:aws:s3:::nobu-terraform-iac-lab-upload/*
```

S3バケットはリージョンを指定して作成するが、バケット名はグローバルで一意である。同じ名前が他のAWSアカウントで使われている場合は作成できない。

## 削除時の注意

S3バケットを削除する前に、中のオブジェクトを削除する必要がある。

オブジェクト削除:

```bash
aws s3 rm s3://nobu-terraform-iac-lab-upload --recursive \
  --profile learning \
  --region ap-northeast-1
```

バケット削除:

```bash
aws s3api delete-bucket \
  --profile learning \
  --region ap-northeast-1 \
  --bucket nobu-terraform-iac-lab-upload
```

EC2からIAM Instance Profileの関連付けを外す場合:

```bash
aws ec2 describe-iam-instance-profile-associations \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=instance-id,Values=<Instance ID> \
  --query 'IamInstanceProfileAssociations[0].AssociationId' \
  --output text
```

```bash
aws ec2 disassociate-iam-instance-profile \
  --profile learning \
  --region ap-northeast-1 \
  --association-id <Association ID>
```

IAMロールからポリシーを外す。

```bash
aws iam detach-role-policy \
  --profile learning \
  --role-name sample-role-web \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
```

Instance ProfileからRoleを外す。

```bash
aws iam remove-role-from-instance-profile \
  --profile learning \
  --instance-profile-name sample-role-web \
  --role-name sample-role-web
```

Instance Profileを削除する。

```bash
aws iam delete-instance-profile \
  --profile learning \
  --instance-profile-name sample-role-web
```

IAMロールを削除する。

```bash
aws iam delete-role \
  --profile learning \
  --role-name sample-role-web
```

