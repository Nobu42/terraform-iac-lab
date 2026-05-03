# 14 Private DNS Setup

## 目的

AWS CLIでRoute 53のPrivate Hosted Zoneを作成し、VPC内だけで利用できる内部DNSを設定する。

この手順では、Private Hosted Zone `home` を作成し、`sample-vpc` に関連付ける。
VPC内のEC2インスタンスから、以下の名前で各リソースへアクセスできるようにする。

- `bastion.home`
- `web01.home`
- `web02.home`
- `db.home`

## 実行環境

この手順は以下の環境で検証しています。

- 実行環境: 実AWS
- リージョン: ap-northeast-1
- AWS CLI: v2
- 対象リソース: Route 53 Private Hosted Zone, EC2, RDS
- 前提:
  - `sample-vpc` が作成済みであること
  - `sample-ec2-bastion` が起動済みであること
  - `sample-ec2-web01` が起動済みであること
  - `sample-ec2-web02` が起動済みであること
  - `sample-db` が作成済みであること
  - VPCのDNS support / DNS hostnames が有効であること

## 設計値

| 項目 | 値 |
| :--- | :--- |
| Private Hosted Zone | home |
| 関連付けVPC | sample-vpc |
| Bastionレコード | bastion.home |
| Web01レコード | web01.home |
| Web02レコード | web02.home |
| DBレコード | db.home |
| TTL | 300 |
| ルーティングポリシー | シンプルルーティング |

## DNS設計

| レコード名 | タイプ | ルーティング先 | 用途 |
| :--- | :--- | :--- | :--- |
| bastion.home | A | Bastion Private IP | VPC内部からの踏み台サーバー参照 |
| web01.home | A | Web01 Private IP | VPC内部からのWeb01参照 |
| web02.home | A | Web02 Private IP | VPC内部からのWeb02参照 |
| db.home | CNAME | RDS Endpoint | VPC内部からのDB接続 |

## スクリプト

- [14_private_dns_setup.sh](../scripts/14_private_dns_setup.sh)

## 実行コマンド

```bash
./14_private_dns_setup.sh
```

## 実AWSでの実行結果

Private Hosted Zone `home` を作成し、`sample-vpc` に関連付けた。

実行時の主な出力:

```text
Private Hosted Zone ID: Z10029083PKCP2RORJ0AY
Bastion Private IP: 10.0.3.249
Web01 Private IP: 10.0.66.158
Web02 Private IP: 10.0.92.212
RDS Endpoint: sample-db.cz0uoiium9n7.ap-northeast-1.rds.amazonaws.com
DNS change is INSYNC.
```

作成されたPrivate DNSレコード:

| Name | Type | Value |
| :--- | :--- | :--- |
| bastion.home | A | 10.0.3.249 |
| web01.home | A | 10.0.66.158 |
| web02.home | A | 10.0.92.212 |
| db.home | CNAME | sample-db.cz0uoiium9n7.ap-northeast-1.rds.amazonaws.com |

## 確認コマンド

Private Hosted ZoneはVPC内でのみ名前解決できる。
そのため、Macローカルではなく、VPC内のEC2インスタンスにSSH接続して確認する。

```bash
ssh web01
```

EC2上でDNS名前解決を確認する。

```bash
dig web01.home
dig web02.home
dig bastion.home
dig db.home
```

`dig` が入っていない場合は、以下でインストールする。

```bash
sudo dnf -y install bind-utils
```

`getent` でも名前解決を確認できる。

```bash
getent hosts web01.home
getent hosts db.home
```

## Private DNS確認結果

Web01上で `web01.home` を名前解決した。

```text
QUESTION SECTION:
;web01.home.                    IN      A

ANSWER SECTION:
web01.home.             300     IN      A       10.0.66.158

SERVER: 10.0.0.2#53(10.0.0.2)
```

`web01.home` がWeb01自身のPrivate IPである `10.0.66.158` に名前解決された。

Web01上で `db.home` を名前解決した。

```text
QUESTION SECTION:
;db.home.                       IN      A

ANSWER SECTION:
db.home.                300     IN      CNAME   sample-db.cz0uoiium9n7.ap-northeast-1.rds.amazonaws.com.
sample-db.cz0uoiium9n7.ap-northeast-1.rds.amazonaws.com. 5 IN A 10.0.89.237

SERVER: 10.0.0.2#53(10.0.0.2)
```

`db.home` はRDS EndpointへのCNAMEとして解決され、その先でRDSのPrivate IPへ解決された。

`SERVER: 10.0.0.2#53` は、VPC内のAmazonProvidedDNSを示している。
Private Hosted Zoneの名前解決が、VPC内DNS Resolver経由で行われていることが分かる。

## RDS接続確認

Web01からPrivate DNS名 `db.home` を使ってRDSに接続できることを確認した。

```bash
mysqladmin ping -u adminuser -p -h db.home
```

実行結果:

```text
mysqld is alive
```

これにより、Webサーバーから `db.home` 経由でRDSに接続できることを確認した。

## Macローカルからの名前解決について

Private Hosted Zoneは、関連付けたVPC内でのみ有効である。
そのため、Macローカルから `dig web01.home` を実行しても名前解決できない。

Macローカルでの実行例:

```text
dig web01.home

status: NXDOMAIN
```

これは異常ではない。
Macは自宅DNSサーバーやインターネットDNSへ問い合わせているが、Private Hosted Zone `home` はAWS VPC内のDNS Resolverからのみ参照できる。

## 学んだこと

- Route 53でPrivate Hosted Zoneを作成できる
- Private Hosted ZoneはVPCに関連付けて利用する
- Private DNS名はVPC内のEC2からのみ名前解決できる
- MacローカルからPrivate DNS名を問い合わせても名前解決できない
- EC2上ではAmazonProvidedDNS `10.0.0.2` 経由でPrivate DNSを解決できる
- EC2やRDSを作り直してIPやEndpointが変わっても、スクリプトを再実行すればDNSレコードを更新できる
- DB接続先を `db.home` にすることで、アプリケーション側の設定を分かりやすくできる

## 注意事項

Private Hosted Zone `home` は、関連付けたVPC内でのみ有効である。
インターネット上には公開されないため、外部から `web01.home` や `db.home` を名前解決することはできない。

`bastion.home`、`web01.home`、`web02.home` はEC2のPrivate IPへ向けている。
EC2を作り直すとPrivate IPが変わるため、その場合はこのスクリプトを再実行してDNSレコードを更新する。

`db.home` はRDS EndpointへのCNAMEとして作成している。
RDSを作り直してEndpointが変わった場合も、このスクリプトを再実行して更新する。

## 削除時の注意

Private Hosted Zoneを削除する場合は、先に作成したレコードを削除する必要がある。
`NS` と `SOA` はHosted Zoneに自動作成される基本レコードであり、通常は手動削除しない。

学習用の削除スクリプトでは、以下の順序で削除する。

1. Private Hosted Zone内の独自レコードを削除
2. Private Hosted Zoneを削除
3. VPCなどのネットワークリソースを削除

Private Hosted ZoneがVPCに関連付いたままでも削除はできるが、レコードが残っていると削除に失敗する。

