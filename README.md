# Terraform IaC Lab

MacBook Air (M4) と自宅の Raspberry Pi 4（DNS）、Ubuntu サーバーを連携させ、AWS クラウドインフラをシミュレートする IaC（Infrastructure as Code）学習環境です。

## 目次
- [Network Topology](#network-topology)
- [コンセプト](#コンセプト)
  - [~/.bashrc (環境自動判別)](#bashrc)
  - [~/.vimrc (開発環境設定)](#vimrc)

- [インストールとセットアップ](#インストールとセットアップ)
  - [Mac (Client Side)](#mac-client-side)
  - [Ubuntu Server (LocalStack)](#ubuntu-server-localstack)
  - [Raspberry Pi (CoreDNS)](#raspberry-pi-coredns)

## コンテンツ
- [AWS構築演習 (LocalStack)](./learning_aws/vpc-setup.md) : ネットワークからEC2構築まで
- [Terraform演習](./execises/) : 基本構文からLambda構築まで

## Network Topology

```text
      [ MacBook Air (M4) ] <--- クライアント (外出先 / 自宅)
               |
               | (DNS Query)      (AWS CLI / Terraform)
               |                   |
  +------------v-------------+     | +-------------------------+
  |  Raspberry Pi 4 (DNS)    |     | |  Ubuntu Server (Target) |
  |  (192.168.40.208)        |     | |  (192.168.40.100)       |
  |                          |     | |                         |
  |  [ CoreDNS ]             |     | |  [ LocalStack ]         |
  |  localstack.lab -------- | ----+ |  (AWS Simulation)       |
  +--------------------------+       +-------------------------+
               |                                ^
               |                                |
               +---[ Internal Private Network ]--+
```
## LocalStack内部ネットワーク
```
[ VPC: sample-vpc (10.0.0.0/16) ]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    │
    │  [ Internet Gateway: sample-igw ] <───> ( Internet )
    │
    ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [ Route Table: sample-rt-public ]                        │
  │  - 0.0.0.0/0  =>  sample-igw                             │
  └──────────────────────────┬───────────────────────────────┘
                             │
            ┌────────────────┴────────────────┐
            ▼                                 ▼
    [ Public Subnet 01 ]              [ Public Subnet 02 ]
    ( 10.0.11.0/24 )                  ( 10.0.12.0/24 )
    [sample-subnet-public01]          [sample-subnet-public02]
    ┌──────────────────┐              ┌──────────────────┐
    │ [SG: sg-bastion] │              │ [SG: sg-elb]     │
    └──────────────────┘              └──────────────────┘
            │                                 │
            ▼                                 ▼
    [ NAT Gateway 01 ]                [ NAT Gateway 02 ]
    (sample-ngw-01)                   (sample-ngw-02)
            │                                 │
━━━━━━━━━━━━│━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│━━━━━━━━━━━━━━━
            │                                 │
  ┌─────────▼───────────────────────┐ ┌─────────▼───────────────────────┐
  │[Route Table: sample-rt-private01]│ │[Route Table: sample-rt-private02]│
  │ - 0.0.0.0/0 => sample-ngw-01     │ │ - 0.0.0.0/0 => sample-ngw-02     │
  └─────────┬───────────────────────┘ └─────────┬───────────────────────┘
            │                                   │
            ▼                                   ▼
    [ Private Subnet 01 ]               [ Private Subnet 02 ]
    ( 10.0.21.0/24 )                    ( 10.0.22.0/24 )
    [sample-subnet-private01]           [sample-subnet-private02]
```

## コンセプト
- **ハイブリッド設計:** 自宅の Ubuntu (192.168.40.100) と外出先の Mac を自動判別し、エンドポイントを自動切り替え。

- **最適化された編集環境:** Terraform の自動整形や C/Python の実行環境を Vim に統合。

###bashrc
ハイブリッド構成のため、Mac 側の ~/.bashrc に以下の判定ロジックを追記しています。
```
# Home Lab モード判定 (localstack.lab が名前解決できるかを確認)
if nslookup localstack.lab > /dev/null 2>&1; then
    # 【自宅モード】
    export LOCALSTACK_HOST=localstack.lab
    export AWS_ENDPOINT_URL="[http://localstack.lab:4566](http://localstack.lab:4566)"
    echo "🏠 Home Lab Mode: localstack.lab connected."
else
    # 【外出先/ソロモード】
    export LOCALSTACK_HOST=localhost
    export AWS_ENDPOINT_URL="http://localhost:4566"
    echo "🚀 Solo Mode: localhost connected."
fi

# AWS CLI で LocalStack エンドポイントを強制的に使うためのエイリアス
alias aws='aws --endpoint-url=$AWS_ENDPOINT_URL'
```
###vimrc
Terraform 開発をサポート機能を~/.vimrcに追記
```
call plug#begin('~/.vim/plugged')
Plug 'sheerun/vim-polyglot'   " 言語別シンタックス
Plug 'itchyny/lightline.vim'  " ステータスライン
Plug 'jiangmiao/auto-pairs'   " 括弧の自動補完
Plug 'hashivim/vim-terraform' " Terraform専用
call plug#end()

set number
set cursorline
set expandtab
set tabstop=4
set shiftwidth=4
set smartindent

" Terraform設定: 保存時に自動フォーマット
autocmd FileType terraform setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2
let g:terraform_fmt_on_save = 1
let g:terraform_align = 1

" 実行ショートカット (Leaderキー(\) + r)
autocmd FileType python nnoremap <buffer> <Leader>r :!python3 %<CR>
autocmd FileType sh nnoremap <buffer> <Leader>r :!bash %<CR>
autocmd FileType terraform nnoremap <buffer> <Leader>r :!terraform validate<CR>
```

## インストールとセットアップ
### Mac (Client Side)
```
brew tap hashicorp/tap
brew install hashicorp/tap/terraform awscli
brew install localstack/tap/localstack-cli
```

### Ubuntu Server (LocalStack) のセットアップ

Ubuntu サーバーを LocalStack 専用のホストとして構築し、外部（Mac）からの接続を許可する設定です。

#### 1. 必要なパッケージのインストール
Docker がインストールされていることを前提として、`localstack-cli` と Python 環境を整備します。

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
#### Ubuntu 側で実行する LocalStack 起動用スクリプト
```
#!/bin/bash
echo "Starting LocalStack (Remote Access Mode)..."
# 外部アクセスを許可して起動
HOSTNAME_EXTERNAL=192.168.40.100 GATEWAY_LISTEN=0.0.0.0 localstack start -d

# ヘルスチェック
echo -n "Waiting for LocalStack to be ready..."
until curl -s http://localhost:4566/_localstack/health | grep -q '"init": "initialized"'; do
    echo -n "."
    sleep 2
done
echo -e "\n LocalStack is Ready!"
```

### Raspberry Pi (CoreDNS)
#### ラズパイを DNS サーバーとして使用し、localstack.lab を Ubuntu の IP に解決させます。
```
# Corefile 設定
# /etc/coredns/Corefile に以下を記述します。

lab:53 {
    hosts /etc/coredns/lab.hosts {
        fallthrough
    }
    log
    errors
}

.:53 {
    forward . 8.8.8.8 8.8.4.4
    cache 30
}
```
#### サービス化 (/etc/systemd/system/coredns.service)
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
```

