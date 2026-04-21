# Terraform IaC Lab

MacBook Pro (M4) と自宅の Ubuntu サーバーを連携させ、AWS クラウドインフラをシミュレートする IaC 学習ラボです。

## コンセプト
- **ハイブリッド設計:** 自宅の Ubuntu (192.168.40.100) と外出先の Mac を自動判別。
- **編集環境:** Linux カーネル開発の流儀（タブ幅8、空白削除）を Vim に反映。

## インストールとセットアップ

### Mac (外出先・ローカル実行)
Homebrew を使用して環境を構築します。

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform awscli
brew install localstack/tap/localstack-cli
```
## UbuntuServer用スクリプト
```
#!/bin/bash

# Ubuntuサーバー側で実施するスクリプト。Ubuntuで実行した後はMac（クライアント）からterraformコマンドを実行する。
# 1. 作業ディレクトリへ移動
cd ~/terraform-iac-lab

# 2. 仮想環境の有効化
source venv/bin/activate

# 3. クリーンアップ
echo " Resetting LocalStack..."
localstack stop > /dev/null 2>&1

# 4. Macからのアクセスを最適化して起動
# HOSTNAME_EXTERNAL に Ubuntu の IP を指定することで、Mac側との整合性を高める。
echo "Starting LocalStack (Remote Access Mode)..."
HOSTNAME_EXTERNAL=192.168.40.100 GATEWAY_LISTEN=0.0.0.0 localstack start -d

# 5. ヘルスチェック（より厳密な判定）
echo -n "⏳ Waiting for LocalStack to be ready..."
until curl -s http://localhost:4566/_localstack/health | grep -q '"init": "initialized"'; do
    echo -n "."
    sleep 2
done
echo -e "\n OK! LocalStack is Ready!"

# 6. Mac側で叩くべきコマンドを表示
echo "--------------------------------------------------------"
echo " Mac Terminal Command:"
echo "export LOCALSTACK_HOST=192.168.40.100"
echo "terraform plan"
echo "--------------------------------------------------------"

localstack status
```
