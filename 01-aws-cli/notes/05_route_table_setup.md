# 05 Route Table Setup

## 目的

AWS CLIでRoute Tableを作成し、Public SubnetとPrivate Subnetに適切なルートを設定する。

Public SubnetはInternet Gatewayへデフォルトルートを向け、インターネットと直接通信できるようにする。Private SubnetはNAT Gatewayへデフォルトルートを向け、外部から直接到達させずに、内側から外側への通信だけを可能にする。

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース: Route Table, Route, Route Table Association
- 前提:
  - `sample-vpc` が作成済みであること
  - `sample-igw` が作成済みで、VPCにアタッチ済みであること
  - `sample-ngw-01` が `available` であること
  - `sample-ngw-02` が `available` であること
  - Public Subnet / Private Subnet が作成済みであること

## ルートテーブル設計

| 項目 | Public用 | Private用 1 | Private用 2 |
| :--- | :--- | :--- | :--- |
| 名前タグ | sample-rt-public | sample-rt-private01 | sample-rt-private02 |
| localルート | 10.0.0.0/16 local | 10.0.0.0/16 local | 10.0.0.0/16 local |
| 外部向けルート | 0.0.0.0/0 -> sample-igw | 0.0.0.0/0 -> sample-ngw-01 | 0.0.0.0/0 -> sample-ngw-02 |
| 関連付けSubnet | sample-subnet-public01<br>sample-subnet-public02 | sample-subnet-private01 | sample-subnet-private02 |
| 用途 | インターネット公開用 | Private Subnet 1a用 | Private Subnet 1c用 |

## スクリプト

- [05_route_table_setup.sh](../scripts/05_route_table_setup.sh)

## 実行コマンド

```bash
./05_route_table_setup.sh
```

## 確認コマンド

```bash
VPC_ID=$(aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-vpc \
  --query 'Vpcs[0].VpcId' \
  --output text)

aws ec2 describe-route-tables \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'RouteTables[*].{Name:Tags[?Key==`Name`].Value|[0],ID:RouteTableId,AssociatedSubnets:Associations[?SubnetId!=`null`].SubnetId,IGW:Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId|[0],NGW:Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId|[0]}' \
  --output table
```
## 実行結果
```
All Route Tables configured and associated.
=== Describe Route Tables ===
-----------------------------------------------------------------------------------
|                               DescribeRouteTables                               |
+-----------------------+-------+-------------------------+-----------------------+
|          ID           |  IGW  |           NGW           |         Name          |
+-----------------------+-------+-------------------------+-----------------------+
|  rtb-037b7603215310e63|  None |  nat-0b2aff9d55c1fe40e  |  sample-rt-private01  |
+-----------------------+-------+-------------------------+-----------------------+
||                               AssociatedSubnets                               ||
|+-------------------------------------------------------------------------------+|
||  subnet-02ec7b661d0076e20                                                     ||
|+-------------------------------------------------------------------------------+|
|                               DescribeRouteTables                               |
+-----------------------+-------+-------------------------+-----------------------+
|          ID           |  IGW  |           NGW           |         Name          |
+-----------------------+-------+-------------------------+-----------------------+
|  rtb-0371bd90ff7ff0ded|  None |  nat-0ad81babbf14ea6e2  |  sample-rt-private02  |
+-----------------------+-------+-------------------------+-----------------------+
||                               AssociatedSubnets                               ||
|+-------------------------------------------------------------------------------+|
||  subnet-01c95baad80822aa9                                                     ||
|+-------------------------------------------------------------------------------+|
|                               DescribeRouteTables                               |
+---------------------------------------+-------------+-------------+-------------+
|                  ID                   |     IGW     |     NGW     |    Name     |
+---------------------------------------+-------------+-------------+-------------+
|  rtb-0068ff5c2f1ddc9c8                |  None       |  None       |  None       |
+---------------------------------------+-------------+-------------+-------------+
|                               DescribeRouteTables                               |
+------------------------+--------------------------+--------+--------------------+
|           ID           |           IGW            |  NGW   |       Name         |
+------------------------+--------------------------+--------+--------------------+
|  rtb-0ebcb8c85b40c4ae6 |  igw-029cd707166a685ee   |  None  |  sample-rt-public  |
+------------------------+--------------------------+--------+--------------------+
||                               AssociatedSubnets                               ||
|+-------------------------------------------------------------------------------+|
||  subnet-0db50251d570b7054                                                     ||
||  subnet-07a6a961295f95887                                                     ||
|+-------------------------------------------------------------------------------+|
```

## 実AWSでの実行結果

Public用Route Table 1つ、Private用Route Table 2つを作成し、それぞれのSubnetへ関連付ける。

| Name | 外部向けルート | 関連付けSubnet |
| :--- | :--- | :--- |
| sample-rt-public | 0.0.0.0/0 -> Internet Gateway | sample-subnet-public01, sample-subnet-public02 |
| sample-rt-private01 | 0.0.0.0/0 -> NAT Gateway 01 | sample-subnet-private01 |
| sample-rt-private02 | 0.0.0.0/0 -> NAT Gateway 02 | sample-subnet-private02 |

## 学んだこと

- Route TableはSubnet単位で関連付ける
- VPC内通信のためのlocalルートはRoute Tableに自動で作成される
- Public Subnetにするには、`0.0.0.0/0` をInternet Gatewayへ向ける必要がある
- Private Subnetから外部へ通信するには、`0.0.0.0/0` をNAT Gatewayへ向ける必要がある
- NAT GatewayをAZごとに用意する場合、同じAZのPrivate Subnetから同じAZのNAT Gatewayを利用する構成にすると、可用性と通信経路の整理に役立つ
- Terraform化する場合、Route Table、Route、Route Table Associationの依存関係を明確に表現する必要がある

## 注意事項

同じスクリプトを複数回実行すると、同じNameタグを持つRoute Tableが重複して作成される可能性がある。

Subnetは同時に1つのRoute Tableに関連付けられる。既に関連付けがあるSubnetへ別のRoute Tableを関連付けると、関連付けが変更される場合がある。

NAT Gatewayは課金対象であるため、この手順以降もNAT Gatewayを利用しない場合は、作業終了後に削除する。

## 削除時の注意

VPC削除時は、先にRoute Tableの関連付けや外部向けルートに依存するリソースを整理する必要がある。

削除順序の例:

1. EC2、ALB、RDSなどRoute Tableを利用するリソースを削除する
2. Route Table Associationを解除する
3. カスタムRoute Tableを削除する
4. NAT Gatewayを削除する
5. Elastic IPを解放する
6. Internet Gatewayをデタッチして削除する
7. Subnetを削除する
8. VPCを削除する


