# 04 NAT Gateway Setup

## 目的

AWS CLIでNAT Gatewayを作成し、Private Subnetからインターネットへアウトバウンド通信できる構成を準備する。

NAT Gatewayは、Private Subnet内のEC2などがインターネットやAWSサービスへ接続するために利用する。外部からPrivate Subnet内のリソースへ直接接続させず、内側から外側への通信だけを許可するための構成である。

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース: Elastic IP, NAT Gateway
- 前提:
  - `sample-vpc` が作成済みであること
  - `sample-subnet-public01` が作成済みであること
  - `sample-subnet-public02` が作成済みであること
  - Internet GatewayがVPCにアタッチ済みであること

## 設計値

| 項目 | 値 |
| :--- | :--- |
| NAT Gateway 01 | sample-ngw-01 |
| NAT Gateway 01 配置先 | sample-subnet-public01 |
| NAT Gateway 02 | sample-ngw-02 |
| NAT Gateway 02 配置先 | sample-subnet-public02 |
| Elastic IP 01 | sample-eip-ngw-01 |
| Elastic IP 02 | sample-eip-ngw-02 |
| Projectタグ | terraform-iac-lab |
| Environmentタグ | learning |

## スクリプト

- [04_nat_gateway_setup.sh](../scripts/04_nat_gateway_setup.sh)

## 実行コマンド

```bash
./04_nat_gateway_setup.sh
```

## 確認コマンド

```bash
aws ec2 describe-nat-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filter Name=tag:Name,Values=sample-ngw-01,sample-ngw-02 \
  --query 'NatGateways[*].{Name:Tags[?Key==`Name`].Value|[0],ID:NatGatewayId,State:State,Subnet:SubnetId,PublicIP:NatGatewayAddresses[0].PublicIp,AllocationId:NatGatewayAddresses[0].AllocationId}' \
  --output table
```

## 実AWSでの実行結果

Public SubnetにNAT Gatewayを2台作成し、それぞれElastic IPを割り当てた。

| Name | State | 配置先Subnet | Elastic IP |
| :--- | :--- | :--- | :--- |
| sample-ngw-01 | available | sample-subnet-public01 | 割り当て済み |
| sample-ngw-02 | available | sample-subnet-public02 | 割り当て済み |

## 学んだこと

- NAT GatewayはPrivate Subnet内のリソースが外部へ通信するために利用する
- NAT GatewayはPublic Subnetに配置する
- Public NAT GatewayにはElastic IPの割り当てが必要
- NAT Gatewayを作成しただけでは、Private Subnetからインターネットへ出られない
- 後続のRoute Table設定で、Private Subnetのデフォルトルート `0.0.0.0/0` をNAT Gatewayへ向ける必要がある
- 高可用性を意識する場合、AZごとにNAT Gatewayを作成し、同じAZのPrivate Subnetから利用する構成にする

## 注意事項

NAT GatewayとElastic IPは課金対象である。

NAT Gatewayは作成されて `available` になった時点から、利用時間に応じた料金が発生する。また、NAT Gatewayを通過したデータ量に応じたデータ処理料金も発生する。

Elastic IPもPublic IPv4アドレスとして課金対象になるため、NAT Gateway削除後にElastic IPを解放し忘れないようにする。

学習目的で作成する場合は、作業完了後に必ず削除する。

## 削除時の注意

NAT Gatewayを削除しても、Elastic IPは自動では解放されない。

削除時は以下の順序で対応する。

1. NAT Gatewayを削除する
2. NAT Gatewayの状態が `deleted` になるまで待つ
3. Elastic IPを解放する

NAT Gatewayの確認コマンド:

```bash
aws ec2 describe-nat-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filter Name=tag:Name,Values=sample-ngw-01,sample-ngw-02 \
  --query 'NatGateways[*].{Name:Tags[?Key==`Name`].Value|[0],ID:NatGatewayId,State:State,AllocationId:NatGatewayAddresses[0].AllocationId}' \
  --output table
```

Elastic IPの確認コマンド:

```bash
aws ec2 describe-addresses \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-eip-ngw-01,sample-eip-ngw-02 \
  --query 'Addresses[*].{Name:Tags[?Key==`Name`].Value|[0],AllocationId:AllocationId,PublicIp:PublicIp,AssociationId:AssociationId}' \
  --output table
```

### 確認結果
```
-------------------------------------------------------------------------------------------------------------------------------------
|                                                        DescribeNatGateways                                                        |
+----------------------------+------------------------+----------------+-----------------+-------------+----------------------------+
|        AllocationId        |          ID            |     Name       |    PublicIP     |    State    |          Subnet            |
+----------------------------+------------------------+----------------+-----------------+-------------+----------------------------+
|  eipalloc-07c216c29ddbaa57e|  nat-0ad81babbf14ea6e2 |  sample-ngw-02 |  54.199.130.148 |  available  |  subnet-0db50251d570b7054  |
|  eipalloc-0e4fe6259565fae72|  nat-0b2aff9d55c1fe40e |  sample-ngw-01 |  52.192.245.95  |  available  |  subnet-07a6a961295f95887  |
+----------------------------+------------------------+----------------+-----------------+-------------+----------------------------+
```
