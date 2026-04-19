" ==========================================
" 1. プラグイン管理 (最小限に絞り込み)
" ==========================================
call plug#begin('~/.vim/plugged')

" 言語別のシンタックス（色付け）強化
Plug 'sheerun/vim-polyglot'

" ステータスラインの視認性向上
Plug 'itchyny/lightline.vim'

call plug#end()

" ==========================================
" 2. 基本設定 (Unix標準の挙動)
" ==========================================
set nocompatible
set encoding=utf-8
set fileencoding=utf-8
set number            " 行番号を表示（デバッグ時に必須）
set cursorline        " カーソル行を強調
set showmatch         " 括弧の対応を表示
set laststatus=2      " ステータスラインを常に表示
set wildmenu          " コマンド補完を視覚的に表示
set title             " 端末のタイトルをファイル名に変更

" 検索設定 (grepに近い挙動)
set ignorecase        " 小文字検索で大文字小文字を無視
set smartcase         " 大文字を含めたら区別する
set incsearch         " インクリメンタルサーチ
set hlsearch          " 検索結果をハイライト
nnoremap <Esc><Esc> :nohlsearch<CR>

" 編集設定 (Unix標準のタブ幅8を意識)
set tabstop=8         " タブ幅は基本8（Unix/Linuxカーネルの流儀）
set shiftwidth=8
set softtabstop=0     " 常に本物のタブを使う設定
set noexpandtab       " スペースではなくタブを使用（Linux開発の掟）
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
" 3. Linuxプログラミング連携
" ==========================================

" --- マニュアル(man)連携 ---
" Kキーでカーソル下の単語の man を Vim 内で開く
runtime ftplugin/man.vim
nnoremap K :Man <C-R><C-W><CR>

" --- タグジャンプ (ctags) ---
" 実行前にシェルで `ctags -R .` を叩いておく必要がある
" Ctrl + ] で定義へジャンプ、Ctrl + t で戻る
set tags=./tags;,tags;

" --- Make / Quickfix 連携 ---
" :make でコンパイルし、エラーがあればその行にジャンプする
" Makefileがあるディレクトリで実行する
nnoremap <Leader>m :make<CR>
nnoremap <Leader>cn :cnext<CR> " 次のエラーへ
nnoremap <Leader>cp :cprevious<CR> " 前のエラーへ

" --- 実行ショートカット ---
autocmd FileType c nnoremap <buffer> <Leader>r :!gcc -Wall % -o %< && ./%<<CR>
autocmd FileType python nnoremap <buffer> <Leader>r :!python3 %<CR>
autocmd FileType sh nnoremap <buffer> <Leader>r :!bash %<CR>

" ==========================================
" 4. 言語別設定
" ==========================================

" C言語 (Linuxカーネルスタイル)
autocmd FileType c setlocal noexpandtab tabstop=8 shiftwidth=8

" Python (PEP8準拠のためPythonのみスペース4)
autocmd FileType python setlocal expandtab tabstop=4 shiftwidth=4 textwidth=88

" Terraform (HashiCorp標準はスペース2つ)
autocmd FileType terraform setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2

" 保存時に自動で terraform fmt を実行する
autocmd BufWritePost *.tf silent! !terraform fmt %
" 実行後に画面が崩れないように再描画
autocmd BufWritePost *.tf silent! redraw!

" ==========================================
" 5. 入力補助・スニペット
" ==========================================

" 保存時に行末の空白を削除
autocmd BufWritePre * :%s/\s\+$//e

" 括弧の補完
inoremap {<CR> {<CR>}<ESC>O
inoremap [ []<Left>
inoremap ( ()<Left>
inoremap " ""<Left>
inoremap ' ''<Left>

" 短縮入力 (iabbr)
iabbr _sh #!/bin/bash
iabbr _py #!/usr/bin/env python3

" main関数の展開
inoremap ;;m int main(int argc, char *argv[])<CR>{<CR>return 0;<CR>}<Esc>O
