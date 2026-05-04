# 19 ElastiCache Setup

## 目的

AWS CLIでAmazon ElastiCache for Redisを作成する。

この手順では、Private SubnetにRedisクラスターを配置し、WebサーバーからRedisへ接続できるようにSecurity Groupを設定する。
Railsアプリケーションのキャッシュ、セッション管理、ジョブキューなどでRedisを利用する準備として構築する。

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース: ElastiCache for Redis, EC2 Security Group, ElastiCache Subnet Group
- 前提:
  - `sample-vpc` が作成済みであること
  - Private Subnetが作成済みであること
  - `sample-sg-web` が作成済みであること
  - WebサーバーがPrivate Subnetに配置されていること

## 設計値

| 項目 | 値 |
| :--- | :--- |
| クラスターエンジン | Redis |
| クラスターモード | 有効 |
| Replication Group ID | sample-elasticache |
| 説明 | Sample Elasticache |
| ノードタイプ | cache.t3.micro |
| シャード数 | 2 |
| シャードあたりのレプリカ | 2 |
| 合計ノード数 | 6 |
| Multi-AZ | 有効 |
| Automatic Failover | 有効 |
| ポート | 6379 |

## サブネットグループ設計

| 項目 | 値 |
| :--- | :--- |
| サブネットグループ名 | sample-elasticache-sg |
| 説明 | Sample ElastiCache Subnet Group |
| VPC | sample-vpc |
| 対象サブネット | Private Subnetすべて |

## Security Group設計

| Security Group | 用途 | 許可する通信 | 送信元 |
| :--- | :--- | :--- | :--- |
| sample-sg-elasticache | ElastiCache Redis | Redis 6379/tcp | sample-sg-web |

WebサーバーからのみRedisへ接続できるようにする。
インターネットやBastionからRedisへ直接接続する構成にはしない。

## スクリプト

- [19_elasticache_setup.sh](../scripts/19_elasticache_setup.sh)

## 実行コマンド

```bash
./19_elasticache_setup.sh
```

## 処理内容

このスクリプトでは以下を行う。

1. `sample-vpc` のVPC IDを取得する
2. Private Subnetを取得する
3. Webサーバー用Security Group `sample-sg-web` を取得する
4. ElastiCache用Security Group `sample-sg-elasticache` を作成する
5. `sample-sg-web` から `sample-sg-elasticache` へのRedis 6379/tcp通信を許可する
6. ElastiCache Subnet Group `sample-elasticache-sg` を作成する
7. ElastiCache Replication Group `sample-elasticache` を作成する
8. Redisクラスターが `available` になるまで待機する
9. Replication Group、Security Group、Subnet Groupの状態を確認する

## 実AWSでの実行結果

ElastiCache用Security Groupを作成した。

```text
ElastiCache Security Group created: sg-0f52eb5e0eaf536e0
```

Webサーバー用Security GroupからRedis 6379/tcpへの接続を許可した。

```text
Redis access from web servers
FromPort: 6379
ToPort: 6379
SourceGroup: sg-08acd1535a99b771d
```

ElastiCache Subnet Groupを作成した。

```text
ElastiCache Subnet Group created: sample-elasticache-sg
```

ElastiCache Replication Groupを作成した。

```text
ElastiCache Replication Group creation started: sample-elasticache
ElastiCache Replication Group is available.
```

作成されたRedisクラスター:

| 項目 | 値 |
| :--- | :--- |
| Replication Group ID | sample-elasticache |
| Status | available |
| ClusterEnabled | True |
| Configuration Endpoint | sample-elasticache.0wkp6l.clustercfg.apne1.cache.amazonaws.com |

Member Clusters:

```text
sample-elasticache-0001-001
sample-elasticache-0001-002
sample-elasticache-0001-003
sample-elasticache-0002-001
sample-elasticache-0002-002
sample-elasticache-0002-003
```

この構成では、以下のように合計6ノードが作成される。

```text
2シャード × (Primary 1 + Replica 2) = 6ノード
```

## 確認コマンド

Replication Groupを確認する。

```bash
aws elasticache describe-replication-groups \
  --profile learning \
  --region ap-northeast-1 \
  --replication-group-id sample-elasticache \
  --query 'ReplicationGroups[*].{ID:ReplicationGroupId,Status:Status,Description:Description,ClusterEnabled:ClusterEnabled,MemberClusters:MemberClusters,ConfigurationEndpoint:ConfigurationEndpoint.Address}' \
  --output table
```

ElastiCache Subnet Groupを確認する。

```bash
aws elasticache describe-cache-subnet-groups \
  --profile learning \
  --region ap-northeast-1 \
  --cache-subnet-group-name sample-elasticache-sg \
  --query 'CacheSubnetGroups[*].{Name:CacheSubnetGroupName,Description:CacheSubnetGroupDescription,VpcId:VpcId,Subnets:Subnets[*].SubnetIdentifier}' \
  --output table
```

ElastiCache用Security Groupを確認する。

```bash
aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=group-name,Values=sample-sg-elasticache \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,Rules:IpPermissions[*].{Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,SourceGroup:UserIdGroupPairs[0].GroupId,Description:UserIdGroupPairs[0].Description}}' \
  --output table
```

## 接続確認

ElastiCacheはPrivate Subnetに配置しているため、Macローカルから直接接続しない。
WebサーバーへSSH接続し、VPC内部から確認する。

```bash
ssh web01
```

Redis CLIが入っていない場合はインストールする。

```bash
sudo dnf -y install redis6
```

パッケージ名が環境によって異なる場合は、以下で検索する。

```bash
sudo dnf search redis
```

Redisクラスターへ接続する。

```bash
redis-cli -c -h sample-elasticache.0wkp6l.clustercfg.apne1.cache.amazonaws.com -p 6379
```

接続後、疎通確認を行う。

```redis
PING
```

応答例:

```text
PONG
```

クラスターモード有効のRedisでは、`redis-cli` に `-c` を付ける。
`-c` を付けることで、クラスターノード間のリダイレクトに追従できる。

## 学んだこと

- ElastiCache for RedisをPrivate Subnetに配置できる
- Redisはインターネットへ公開せず、Webサーバーからのみ接続する構成にできる
- ElastiCache Subnet Groupで、Redisを配置するSubnetを指定する
- Security Groupの送信元にWebサーバー用Security Groupを指定できる
- クラスターモード有効では、Configuration Endpointを使って接続する
- シャード数とレプリカ数によって、作成されるノード数が変わる
- Redis接続確認は、VPC内のEC2から行う必要がある

## 注意事項

この構成では、以下の通り合計6ノードが作成される。

```text
2シャード × (Primary 1 + Replica 2) = 6ノード
```

`cache.t3.micro` であってもノード数が多いため、学習後は必ず削除する。

ElastiCacheはPrivate Subnetに配置するため、Macローカルから直接接続できない。
確認はWebサーバーなど、同じVPC内のEC2から行う。

Redisのエンドポイントは作成ごとに変わる可能性がある。
Railsアプリケーションから利用する場合は、環境変数でRedis URLを渡す運用にする。

## 削除時の注意

ElastiCacheを削除する場合は、Replication Groupを削除する。

```bash
aws elasticache delete-replication-group \
  --profile learning \
  --region ap-northeast-1 \
  --replication-group-id sample-elasticache \
  --no-retain-primary-cluster
```

削除完了を待つ。

```bash
aws elasticache wait replication-group-deleted \
  --profile learning \
  --region ap-northeast-1 \
  --replication-group-id sample-elasticache
```

Replication Group削除後、Subnet GroupとSecurity Groupを削除する。

```bash
aws elasticache delete-cache-subnet-group \
  --profile learning \
  --region ap-northeast-1 \
  --cache-subnet-group-name sample-elasticache-sg
```

```bash
aws ec2 delete-security-group \
  --profile learning \
  --region ap-northeast-1 \
  --group-name sample-sg-elasticache
```

Security Groupは、ElastiCacheから参照されている間は削除できない。
必ずReplication Group削除後に削除する。

