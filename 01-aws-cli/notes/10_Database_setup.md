# 10 Database Setup

## 目的

AWS CLIでRDS MySQLインスタンスを作成する。

DBはPrivate Subnetに配置し、インターネットから直接接続できない構成にする。WebサーバーからのみMySQLの3306番ポートで接続できるようにSecurity Groupで制御する。

RDSは、AWSがOSやDB基盤の運用を管理するマネージドなリレーショナルデータベースサービスである。EC2上にDBを自前構築する場合と比べて、バックアップ、パッチ適用、Multi-AZ構成、監視などを利用しやすい。

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース:
  - Security Group
  - DB Parameter Group
  - DB Option Group
  - DB Subnet Group
  - RDS DB Instance
- 前提:
  - `sample-vpc` が作成済みであること
  - `sample-subnet-private01` が作成済みであること
  - `sample-subnet-private02` が作成済みであること
  - `sample-sg-web` が作成済みであること

## 設計値

| 項目 | 値 |
| :--- | :--- |
| DB識別子 | sample-db |
| DBエンジン | MySQL |
| エンジンバージョン | 8.0 |
| インスタンスクラス | db.t3.micro |
| ストレージ | 20GB |
| Public Access | 無効 |
| Multi-AZ | 無効 |
| Backup Retention | 0日 |
| DB Subnet Group | sample-db-subnet |
| DB Parameter Group | sample-db-pg |
| DB Option Group | sample-db-og |
| DB Security Group | sample-sg-db |
| DB Port | 3306 |
| Master Username | adminuser |

## Security Group設計

| Security Group | 用途 | 許可する通信 | 送信元 |
| :--- | :--- | :--- | :--- |
| sample-sg-db | RDS MySQL | MySQL 3306/tcp | sample-sg-web |

## スクリプト

- [10_Database_setup.sh](../scripts/10_Database_setup.sh)

## 実行前の準備

DBパスワードはスクリプトに直書きしない。実行前に環境変数として一時的に設定する。

```bash
export DB_MASTER_PASSWORD='your-strong-password'
```

実行後、不要であれば環境変数を削除する。

```bash
unset DB_MASTER_PASSWORD
```

## 実行コマンド

```bash
./10_Database_setup.sh
```

## 確認コマンド

RDSインスタンスの状態を確認する。

```bash
aws rds describe-db-instances \
  --profile learning \
  --region ap-northeast-1 \
  --db-instance-identifier sample-db \
  --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,Class:DBInstanceClass,Endpoint:Endpoint.Address,Port:Endpoint.Port,PubliclyAccessible:PubliclyAccessible,MultiAZ:MultiAZ}' \
  --output table
```

DB用Security Groupを確認する。

```bash
aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=group-name,Values=sample-sg-db \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,Rules:IpPermissions[*].{Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,SourceGroup:UserIdGroupPairs[0].GroupId,Description:UserIdGroupPairs[0].Description}}' \
  --output table
```

DB Subnet Groupを確認する。

```bash
aws rds describe-db-subnet-groups \
  --profile learning \
  --region ap-northeast-1 \
  --db-subnet-group-name sample-db-subnet \
  --query 'DBSubnetGroups[*].{Name:DBSubnetGroupName,VpcId:VpcId,Status:SubnetGroupStatus,Subnets:Subnets[*].SubnetIdentifier}' \
  --output table
```

## 実AWSでの実行結果

RDS MySQLインスタンスをPrivate Subnet向けのDB Subnet Groupに作成した。

| 項目 | 結果 |
| :--- | :--- |
| DB Instance | sample-db |
| Status | available |
| Engine | mysql |
| Instance Class | db.t3.micro |
| Port | 3306 |
| Publicly Accessible | False |
| Multi-AZ | False |
| Endpoint | 作成済み |

DB用Security Groupでは、Webサーバー用Security GroupからのMySQL接続のみを許可した。

| 通信 | Port | Source |
| :--- | :--- | :--- |
| MySQL | 3306/tcp | sample-sg-web |

## WebサーバーからのRDS接続確認

RDS作成後、Private Subnet上のWebサーバーからRDS MySQLへ接続できることを確認した。

確認は `web01` にSSH接続して実施した。

```bash
ssh web01
```

Amazon Linux 2023では、書籍などで使われることがある `mysql` パッケージ名ではインストールできない場合がある。

```bash
sudo yum -y install mysql
```

実行結果:

```text
No match for argument: mysql
Error: Unable to find a match: mysql
```

利用可能なMariaDB/MySQL関連パッケージを確認する。

```bash
sudo dnf search mariadb
```

MySQL互換クライアントとして `mariadb105` をインストールする。

```bash
sudo dnf -y install mariadb105
```

インストール後、`mysql` コマンドが使えることを確認する。

```bash
mysql --version
```

確認結果:

```text
mysql  Ver 15.1 Distrib 10.5.29-MariaDB, for Linux (x86_64)
```

RDSのエンドポイントを確認する。

```bash
aws rds describe-db-instances \
  --profile learning \
  --region ap-northeast-1 \
  --db-instance-identifier sample-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

`web01` からRDS MySQLへ接続確認する。

```bash
mysqladmin ping \
  -u adminuser \
  -p \
  -h <RDS Endpoint>
```

確認結果:

```text
mysqld is alive
```

この結果により、`web01` からRDS MySQLへ接続できることを確認した。

```text
web01
  -> sample-sg-web
  -> sample-sg-db
  -> RDS MySQL :3306
```

## 接続確認で詰まった点

最初に誤ったRDSエンドポイントを指定したため、以下のエラーが発生した。

```text
Unknown MySQL server host
```

これはSecurity Groupやポートの問題ではなく、ホスト名の名前解決に失敗している状態である。

RDSのエンドポイントは手入力せず、以下のコマンドで取得した値を使う。

```bash
aws rds describe-db-instances \
  --profile learning \
  --region ap-northeast-1 \
  --db-instance-identifier sample-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

また、スクリプトではDBユーザー名を以下のように設定している。

```bash
DB_MASTER_USERNAME="adminuser"
```

そのため、接続確認時のユーザー名も `adminuser` を使用する。

```bash
mysqladmin ping -u adminuser -p -h <RDS Endpoint>
```

## 学んだこと

- RDSはマネージドなリレーショナルデータベースサービスである
- RDSをPrivate Subnetに配置するにはDB Subnet Groupを作成する
- DB Subnet Groupには複数AZのSubnetを指定できる
- `--no-publicly-accessible` により、インターネットから直接到達できないDBにできる
- DB用Security Groupでは、Webサーバー用Security Groupからの3306/tcpのみを許可した
- DBパスワードはスクリプトに直書きせず、環境変数などで渡す
- RDSは作成完了まで時間がかかるため、`aws rds wait db-instance-available` で待機する
- Terraform化する場合、DB Subnet Group、Security Group、Parameter Group、Option Group、DB Instanceの依存関係を整理する必要がある
- Amazon Linux 2023では、`mysql` というパッケージ名でMySQLクライアントをインストールできない場合がある
- RDS MySQLへの接続確認には、MariaDBクライアントを利用できる
- `Unknown MySQL server host` は、主にRDSエンドポイント名の誤りやDNS解決失敗を示す
- `mysqld is alive` が表示されれば、MySQLサーバーへの接続確認は成功している

## 注意事項

RDSは課金対象である。学習が終わったら削除する。

DBパスワードをGitHubやドキュメントに記載しない。誤って公開した場合は、DBを削除するか、パスワードを変更する。

今回の構成では学習用に以下を設定している。

- Multi-AZ無効
- Backup Retention 0日
- Deletion Protection無効

実運用では、バックアップ保持期間、Multi-AZ、削除保護、監視、パスワード管理を要件に合わせて設計する。

## 削除時の注意

RDSは削除に時間がかかる。削除時は、必要に応じて最終スナップショットを取得する。

学習環境でスナップショットを残さず削除する例:

```bash
aws rds delete-db-instance \
  --profile learning \
  --region ap-northeast-1 \
  --db-instance-identifier sample-db \
  --skip-final-snapshot \
  --delete-automated-backups
```

削除完了まで待つ。

```bash
aws rds wait db-instance-deleted \
  --profile learning \
  --region ap-northeast-1 \
  --db-instance-identifier sample-db
```

RDS削除後、DB用Security Groupを削除する。

```bash
aws ec2 delete-security-group \
  --profile learning \
  --region ap-northeast-1 \
  --group-name sample-sg-db
```

DB Subnet Groupを削除する。

```bash
aws rds delete-db-subnet-group \
  --profile learning \
  --region ap-northeast-1 \
  --db-subnet-group-name sample-db-subnet
```

DB Parameter Groupを削除する。

```bash
aws rds delete-db-parameter-group \
  --profile learning \
  --region ap-northeast-1 \
  --db-parameter-group-name sample-db-pg
```

DB Option Groupを削除する。

```bash
aws rds delete-option-group \
  --profile learning \
  --region ap-northeast-1 \
  --option-group-name sample-db-og
```

