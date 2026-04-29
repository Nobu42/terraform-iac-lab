# インストールとセットアップ
## Mac (Client Side)
```
brew tap hashicorp/tap
brew install hashicorp/tap/terraform awscli
brew install localstack/tap/localstack-cli
```

## Ubuntu Server (LocalStack) のセットアップ

Ubuntu サーバーを LocalStack 専用のホストとして構築し、外部（Mac）からの接続を許可する設定。

### 1. 必要なパッケージのインストール
Docker がインストールされていることを前提として、`localstack-cli` と Python 環境を整備する。

```bash
# Python3 と venv のインストール
sudo apt update
sudo apt install -y python3-pip python3-venv

# 作業ディレクトリの作成と仮想環境の構築
mkdir -p ~/terraform-iac-lab
cd ~/terraform-iac-lab
python3 -m venv venv
source venv/bin/activate

# LocalStack CLI のインストール
pip install localstack
```
### Ubuntu 側で実行する LocalStack 起動用スクリプト
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

# 4. Macからのアクセスを最適化して起動（EC2/Lambdaのコンテナ実行モードを有効化）
echo "Starting LocalStack (Resetting to stable mode)..."
HOSTNAME_EXTERNAL=192.168.40.100 \
GATEWAY_LISTEN=0.0.0.0 \
EC2_VM_MANAGER=docker \
localstack start -d

# 5. 静かに待機（画面を汚さない）
echo -n " Initializing..."
source venv/bin/activate
localstack wait -t 10 > /dev/null 2>&1
echo -e "\r LocalStack is Ready!    " # \r で上書きして消去
```

## Raspberry Pi (CoreDNS)
### ラズパイを DNS サーバーとして使用し、localstack.lab を Ubuntu の IP に解決させます。
```
# Corefile 設定
# /etc/coredns/Corefile に以下を記述します。

# .lab ドメインの設定
lab:53 {
    hosts /etc/coredns/lab.hosts {
        # 自分のドメイン以外は次に渡す
        fallthrough
    }
    log
    errors
}

# それ以外の全般設定（インターネット用）
.:53 {
    forward . 8.8.8.8 8.8.4.4
    log
    errors
    cache 30
}

```
### サービス化 (/etc/systemd/system/coredns.service)
```
[Unit]
Description=CoreDNS DNS server
After=network.target

[Service]
PermissionsStartOnly=true
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
User=nobu
ExecStart=/usr/local/bin/coredns -conf /etc/coredns/Corefile
Restart=on-failure

[Install]
WantedBy=multi-user.target

