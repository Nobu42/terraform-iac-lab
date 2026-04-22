# Terraform IaC Lab
# Terraform IaC Lab

MacBook Air (M4) と自宅の Raspberry Pi 4（DNS）、Ubuntu サーバーを連携させ、AWS クラウドインフラをシミュレートする IaC（Infrastructure as Code）学習環境です。

## 🌐 Network Topology (Home Lab)

```text
       [ MacBook Air (M4) ]
               |
               | (Terraform / AWS CLI)
               v
  +--------------------------+      +-------------------------+
  |  Raspberry Pi 4          |      |  Ubuntu Server          |
  |  (192.168.40.208)        |      |  (192.168.40.100)       |
  |                          |      |                         |
  |  +--------------------+  |      |  +-------------------+  |
  |  |      CoreDNS       |--|----->|  |    LocalStack     |  |
  |  |  (localstack.lab)  |  |      |  |  (AWS Simulation) |  |
  |  +--------------------+  |      |  +-------------------+  |
  +--------------------------+      +-------------------------+
               |                                 ^
               |                                 |
               +---[ Internal Private Network ]--+
```

MacBook Air (M4) と自宅の ラズパイ4（DNS)、Ubuntu サーバーを連携させ、AWS クラウドインフラをシミュレートする IaC 学習ラボです。

## コンセプト
- **ハイブリッド設計:** 自宅の Ubuntu (192.168.40.100) と外出先の Mac を自動判別。
- **編集環境:** bashrc設定とvimrc。
### ~/.bashrc
```
# macの~/.bashrcに以下を追記。ハイブリッド構成のため
# Created by `pipx` on 2025-12-07 09:41:39
export PATH="$PATH:/Users/nobu/.local/bin"
# Ubuntuがネットワーク内にいるか確認して行き先を自動で決める
if ping -c 1 -t 1 192.168.40.100 > /dev/null 2>&1; then
    # Ubuntuが見つかる場合（自宅にいる時）
    export LOCALSTACK_HOST=192.168.40.100
    export AWS_ENDPOINT_URL="http://192.168.40.100:4566"
else
    # Ubuntuが見つからない場合（外出先やMac単体で動かす時）
    export LOCALSTACK_HOST=localhost
    export AWS_ENDPOINT_URL="http://localhost:4566"
fi

# どちらの場合でも「aws」だけで動くようにエイリアスを設定
alias aws='aws --endpoint-url=$AWS_ENDPOINT_URL'
```
### ~/.vimrc
```
" ==========================================
" 1. プラグイン管理
" ==========================================
call plug#begin('~/.vim/plugged')

Plug 'sheerun/vim-polyglot' " 言語別シンタックス
Plug 'itchyny/lightline.vim' " ステータスライン
Plug 'jiangmiao/auto-pairs'  " ★【追加】スマートな括弧補完
Plug 'hashivim/vim-terraform' " ★【追加】Terraform専用プラグイン（超便利です）

call plug#end()

" ==========================================
" 2. 基本設定 (モダンな開発スタイルに調整)
" ==========================================
set nocompatible
set encoding=utf-8
set fileencoding=utf-8
set number
set cursorline
set showmatch
set laststatus=2
set wildmenu
set title

" 検索設定
set ignorecase
set smartcase
set incsearch
set hlsearch
nnoremap <Esc><Esc> :nohlsearch<CR>

" 編集設定 (グローバル設定を「スペース4」に変更)
set expandtab       " タブの代わりにスペースを使用（現代の開発の標準）
set tabstop=4       " タブを表示するときの幅
set shiftwidth=4    " 自動インデント時の幅
set softtabstop=4
set autoindent
set smartindent
set nowrap
set backspace=indent,eol,start
set scrolloff=5
set sidescrolloff=5
set clipboard+=unnamedplus

filetype plugin indent on
syntax on

" ==========================================
" 3. 言語別設定 (ここが Terraform 対策の肝です)
" ==========================================

" Terraform (HashiCorp標準: スペース2つ)
autocmd FileType terraform setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2
" .tfファイルを確実にterraformタイプとして認識させる
autocmd BufRead,BufNewFile *.tf set filetype=terraform

" Terraform保存時の自動フォーマット (vim-terraformの機能を利用)
let g:terraform_fmt_on_save = 1
let g:terraform_align = 1 " = の位置を綺麗に揃えてくれる

" C言語 (Linuxカーネルスタイルを維持したい場合のみタブ8)
autocmd FileType c setlocal noexpandtab tabstop=8 shiftwidth=8

" Python (PEP8)
autocmd FileType python setlocal expandtab tabstop=4 shiftwidth=4

" ==========================================
" 4. 入力補助・ショートカット
" ==========================================

" 保存時に行末の空白を削除
autocmd BufWritePre * :%s/\s\+$//e

" マニュアル連携
runtime ftplugin/man.vim
nnoremap K :Man <C-R><C-W><CR>

" 実行ショートカット (Leaderキー = \)
autocmd FileType c nnoremap <buffer> <Leader>r :!gcc -Wall % -o %< && ./%<<CR>
autocmd FileType python nnoremap <buffer> <Leader>r :!python3 %<CR>
autocmd FileType sh nnoremap <buffer> <Leader>r :!bash %<CR>
" Terraformのバリデーションを実行
autocmd FileType terraform nnoremap <buffer> <Leader>r :!terraform validate<CR>

" main関数の展開
inoremap ;;m int main(int argc, char *argv[])<CR>{<CR>return 0;<CR>}<Esc>O
```

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

7. 自宅ラズパイをDNSとして使用
```
# CoreDNSの最新版（1.11.1）をダウンロード
wget https://github.com/coredns/coredns/releases/download/v1.11.1/coredns_1.11.1_linux_arm64.tgz

# 解凍して実行ファイルを配置
tar -xvzf coredns_1.11.1_linux_arm64.tgz
sudo mv coredns /usr/local/bin/

# バージョン確認
coredns --version

# 設定用ディレクトリ作成
sudo mkdir -p /etc/coredns
sudo vi /etc/coredns/Corefile

# 以下の内容を貼り付ける
.:53 {
    # ログを出力して動きを見えるようにする
    log
    errors

    # 自分のドメイン設定（後でここを編集してLocalStackに繋ぎます）
    # 外部の問い合わせはGoogleのDNSに飛ばす
    forward . 8.8.8.8 8.8.4.4

    # キャッシュを有効にして高速化
    cache 30
}
```
