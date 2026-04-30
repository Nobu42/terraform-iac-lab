# 03 Internet Gateway Setup

## 目的

AWS CLIでInternet Gatewayを作成し、VPCにアタッチする。

Internet Gatewayは、VPC内のリソースがインターネットと通信するための出口として利用する。Public Subnetをインターネットに接続するには、Internet Gatewayの作成に加えて、Route Tableで `0.0.0.0/0` をInternet Gatewayへ向ける必要がある。

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース: Internet Gateway
- 前提: `sample-vpc` が作成済みであること

## 設計値

| 項目 | 値 |
| :--- | :--- |
| Internet Gateway名 | sample-igw |
| アタッチ先VPC | sample-vpc |
| Projectタグ | terraform-iac-lab |
| Environmentタグ | learning |

## スクリプト

- [03_internetgateway_setup.sh](../scripts/03_internetgateway_setup.sh)

## 実行コマンド

```bash
./03_internetgateway_setup.sh
```

## 確認コマンド
```
aws ec2 describe-internet-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-igw \
  --query 'InternetGateways[*].{ID:InternetGatewayId,Name:Tags[?Key==`Name`].Value|[0],VPC:Attachments[0].VpcId,State:Attachments[0].State}' \
  --output table
```

## 確認結果
```
-------------------------------------------------------------------------------
|                          DescribeInternetGateways                           |
+------------------------+-------------+------------+-------------------------+
|           ID           |    Name     |   State    |           VPC           |
+------------------------+-------------+------------+-------------------------+
|  igw-15cdea338144d846f |  sample-igw |  available |  vpc-f840017528abd02e7  |
+------------------------+-------------+------------+-------------------------+
```

### 学んだこと
* *Internet GatewayはVPCにアタッチして利用する*
* *Internet Gatewayを作成しただけでは、Subnetはまだインターネットへ出られない*
* *Public Subnetとして通信させるには、Route Tableで 0.0.0.0/0 のルートをInternet Gatewayへ向ける必要がある*
* *1つのVPCにアタッチできるInternet Gatewayは基本的に1つ*
* *後続のRoute Table作成では、Internet Gateway IDを参照してデフォルトルートを作成する*

### 注意事項
同じスクリプトを複数回実行すると、同じNameタグを持つInternet Gatewayが重複して作成される可能性がある。

また、既にInternet GatewayがアタッチされているVPCに対して、別のInternet Gatewayをアタッチしようとするとエラーになる。

実行前に既存のInternet Gatewayを確認する。
