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

# 1. 作業ディレクトリへ移動
cd ~/terraform-iac-lab

# 2. 仮想環境の有効化 (実行時に `source` する必要があるため案内を表示)
if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
    echo "Note: Please run this script with 'source ./start.sh' to activate the venv."
fi
source venv/bin/activate

# 3. すでに動いているLocalStackがあれば停止（クリーンな状態にする）
echo " Resetting LocalStack..."
localstack stop > /dev/null 2>&1

# 4. Macからの接続を許可してバックグラウンド起動
echo " Starting LocalStack for remote access..."
GATEWAY_LISTEN=0.0.0.0 localstack start -d

# 5. LocalStackが「Ready」になるまで待機（インフラ屋のこだわり）
echo -n " Waiting for LocalStack to be ready..."
while ! curl -s http://localhost:4566/_localstack/health | grep -q '"s3": "available"'; do
    echo -n "."
    sleep 2
done
echo -e "\nOK! LocalStack is Ready! Mac (192.168.40.100) can now connect."

# 6. 現在の状態を表示
localstack status
```

