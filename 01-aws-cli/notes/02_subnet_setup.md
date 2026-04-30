# 02 Subnet Setup

## 目的

AWS CLIでPublic SubnetとPrivate Subnetを作成し、VPC内のネットワーク分割を確認する。

Public Subnetはインターネット向けリソースを配置する領域、Private Subnetは外部から直接到達させたくないアプリケーションサーバーやデータベースを配置する領域として設計する。

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース: Subnet
- 前提: `sample-vpc` が作成済みであること

## サブネット設計

| 区分 | サブネット名 | AZ | IPv4 CIDR | Public IP自動割当 |
| :--- | :--- | :--- | :--- | :--- |
| Public 1 | sample-subnet-public01 | ap-northeast-1a | 10.0.0.0/20 | 有効 |
| Public 2 | sample-subnet-public02 | ap-northeast-1c | 10.0.16.0/20 | 有効 |
| Private 1 | sample-subnet-private01 | ap-northeast-1a | 10.0.64.0/20 | 無効 |
| Private 2 | sample-subnet-private02 | ap-northeast-1c | 10.0.80.0/20 | 無効 |

## スクリプト

- [02_subnet_setup.sh](../scripts/02_subnet_setup.sh)

## 実行コマンド

```bash
./02_subnet_setup.sh
```

## 確認コマンド
```
aws ec2 describe-subnets \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-subnet-public01,sample-subnet-public02,sample-subnet-private01,sample-subnet-private02 \
  --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value|[0],AZ:AvailabilityZone,CIDR:CidrBlock,PublicIP:MapPublicIpOnLaunch,ID:SubnetId}' \
  --output table
```

## 確認結果
```
--------------------------------------------------------------------------------------------------------
|                                            DescribeSubnets                                           |
+-----------------+---------------+----------------------------+---------------------------+-----------+
|       AZ        |     CIDR      |            ID              |           Name            | PublicIP  |
+-----------------+---------------+----------------------------+---------------------------+-----------+
|  ap-northeast-1c|  10.0.80.0/20 |  subnet-01c95baad80822aa9  |  sample-subnet-private02  |  False    |
|  ap-northeast-1c|  10.0.16.0/20 |  subnet-0db50251d570b7054  |  sample-subnet-public02   |  True     |
|  ap-northeast-1a|  10.0.0.0/20  |  subnet-07a6a961295f95887  |  sample-subnet-public01   |  True     |
|  ap-northeast-1a|  10.0.64.0/20 |  subnet-02ec7b661d0076e20  |  sample-subnet-private01  |  False    |
+-----------------+---------------+----------------------------+---------------------------+-----------+
```

