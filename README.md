# AWS Infrastructure Learning Lab

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)

このリポジトリは、AWS CLI（シェルスクリプト）を用いて、実環境でのインフラ構築を体系的に学ぶためのラボです。
Terraform（IaCツール）を導入する前に、まずシェルスクリプトによる自動化を経験することで、各リソースの依存関係やツールの導入メリットを比較・検証することを目的としています。

##  目的
- AWS CLIによるリソース操作の習熟（IaCの基礎体力向上）
- 有料枠を使用し、コスト意識（作成・監視・削除）を持った実務に近い運用練習
- ベストプラクティスに基づいた堅牢なインフラ構成の再現

##  ディレクトリ構成
- `learning_aws/`: 各チャプターごとの解説ドキュメント
- `learning_aws/Shell/`: 実際に実行する AWS CLI スクリプト（本番用）
- `dotfiles/`: 効率的な開発のための設定ファイル（bashrc, vimrc）
- `docs/`: ネットワーク設計図および各種コマンドリファレンス

##  学習ステップ（AWS CLI & Shell Script）

書籍の構成に沿って、ステップバイステップでシェルスクリプトによる構築を進めます。

1. **[VPC 構築](./learning_aws/01_vpc_setup.md)** - ネットワークの土台
   - スクリプト: `01_vpc_setup.sh`
2. **[サブネット設計](./learning_aws/02_subnet_setup.md)** - Public/Private の切り分け
3. **[IGW 設定](./learning_aws/03_internetgateway_setup.md)** - インターネットへの出口
4. **[NAT Gateway](./learning_aws/04_nat_gateway_setup.md)** - プライベートサブネットの通信確保
5. **[ルートテーブル](./learning_aws/05_route_table_setup.md)** - パケット経路の定義
6. **[セキュリティグループ](./learning_aws/06_security_group_setup.md)** - 仮想ファイアウォール
7. **[踏み台サーバー](./learning_aws/07_bastion_server_setup.md)** - セキュアな管理用入口
8. **[Web サーバー (EC2)](./learning_aws/08_web_server_setup.md)** - アプリケーション基盤と多段 SSH
9. **[ロードバランサー (ALB)](./learning_aws/09_LoadBalancer_setup.md)** - 高可用性と負荷分散
10. **[データベース (RDS)](./learning_aws/10_Database_setup.md)** - マルチAZによるデータ冗長化

---

##  コスト・ポリシー
本プロジェクトでは有料リソースを使用するため、以下の運用を徹底します。
- **タグ管理:** `Project: Learning` タグを全リソースに付与し、コスト追跡を容易にする。
- **即時削除:** 学習終了後は、削除スクリプト（順次作成予定）を用いてリソースを速やかに破棄する。
- **最小構成:** 原則として `t3.nano` や `t3.micro` 等の最小インスタンスタイプを選択する。

##  Network Architecture
書籍の設計に基づいた論理構成図です。

![Network Architecture](./docs/Network_Architecture.png?v=2)


