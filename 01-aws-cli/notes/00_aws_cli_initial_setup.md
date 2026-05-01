# 00 AWS CLI Initial Setup

## 目的

AWS CLIで実AWS環境へ接続するための初期設定を行う。

この手順では、IAMユーザーのアクセスキーをAWS CLIに設定し、操作対象のAWSアカウント、IAMユーザー、リージョンが正しいことを確認する。

## 前提

- AWSアカウントを作成済みであること
- rootユーザーにMFAを設定済みであること
- 作業用IAMユーザーを作成済みであること
- IAMユーザーのアクセスキーとシークレットアクセスキーを発行済みであること
- AWS CLI v2をインストール済みであること

## AWS CLIプロファイル設定

このリポジトリでは、学習用プロファイルとして `learning` を使用する。

```bash
aws configure --profile learning
```

入力例:

```text
AWS Access Key ID [None]: <IAMユーザーのアクセスキー>
AWS Secret Access Key [None]: <IAMユーザーのシークレットアクセスキー>
Default region name [None]: ap-northeast-1
Default output format [None]: json
```

## LocalStack設定の解除

LocalStack用のendpointやaliasが残っていると、実AWSではなくLocalStackへ接続してしまう。

実AWSを操作する前に、必要に応じて以下を実行する。

```bash
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST
```

現在の `aws` コマンドがaliasになっていないか確認する。

```bash
type -a aws
alias aws
```

期待する状態:

```text
aws is /opt/homebrew/bin/aws
```

## 接続確認

現在の認証情報で、どのAWSアカウント・IAMユーザーとして操作しているか確認する。

```bash
aws sts get-caller-identity \
  --profile learning
```

正常な例:

```json
{
  "UserId": "********",
  "Account": "<AWSアカウントID>",
  "Arn": "arn:aws:iam::<AWSアカウントID>:user/<IAMユーザー名>"
}
```

`000000000000` や `arn:aws:iam::000000000000:root` が表示される場合は、LocalStack向けのendpointやaliasが有効になっている可能性がある。

## リージョン確認

プロファイルに設定されたリージョンを確認する。

```bash
aws configure get region --profile learning
```

期待値:

```text
ap-northeast-1
```

必要に応じて、東京リージョンを設定する。

```bash
aws configure set region ap-northeast-1 --profile learning
```

## 読み取りコマンドで確認

作成系コマンドを実行する前に、読み取り専用コマンドで接続確認を行う。

リージョン一覧:

```bash
aws ec2 describe-regions \
  --profile learning \
  --output table
```

東京リージョンのVPC一覧:

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --output table
```

## 実行時の基本ルール

実AWSを操作するスクリプトでは、以下を明示する。

```bash
PROFILE="learning"
REGION="ap-northeast-1"
```

AWS CLIコマンドでは、原則として以下を付ける。

```bash
--profile "$PROFILE"
--region "$REGION"
```

LocalStack向け設定の影響を避けるため、スクリプト冒頭で以下を実行する。

```bash
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST
```

## トラブルシュート

### `000000000000:root` が表示される

`aws sts get-caller-identity` の結果が以下のようになる場合:

```json
{
  "UserId": "000000000000",
  "Account": "000000000000",
  "Arn": "arn:aws:iam::000000000000:root"
}
```

実AWSではなくLocalStackへ接続している可能性が高い。

確認:

```bash
echo $AWS_ENDPOINT_URL
echo $LOCALSTACK_HOST
type -a aws
alias aws
aws configure get endpoint_url --profile learning
```

対応:

```bash
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST
```

再確認:

```bash
aws sts get-caller-identity \
  --profile learning \
  --region ap-northeast-1
```

### `UnauthorizedOperation` が表示される

AWS CLIの認証は成功しているが、IAMユーザーに対象操作の権限がない場合に発生する。

例:

```text
An error occurred (UnauthorizedOperation) when calling the CreateVpc operation:
You are not authorized to perform this operation.
```

対応:

- IAMユーザーに必要な権限が付与されているか確認する
- 学習初期は `AmazonEC2FullAccess` や `AdministratorAccess` で検証する
- 将来的には最小権限のIAMポリシーへ見直す

## 注意事項

rootユーザーのアクセスキーは作成しない。

実AWSの操作には、作業用IAMユーザーまたはIAM Identity Centerの認証情報を使用する。

アクセスキー、シークレットアクセスキー、`.pem` ファイルはGitHubにpushしない。

`.gitignore` に以下を含める。

```gitignore
*.pem
*.key
```

