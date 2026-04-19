# --------------------------------------
# Homebrew 基本 PATH（Homebrew の bin/sbin を優先）
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

# Go 言語
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

# pyenv Python 3.13.7 を優先
# export PATH="$PYENV_ROOT/versions/3.13.7/bin:$PATH"

# Homebrew sqlite
export PATH="/opt/homebrew/opt/sqlite/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/sqlite/lib"
export CPPFLAGS="-I/opt/homebrew/opt/sqlite/include"
export PKG_CONFIG_PATH="/opt/homebrew/opt/sqlite/lib/pkgconfig"

# Homebrew tcl-tk（Tkinter 用）
export PATH="/opt/homebrew/opt/tcl-tk/bin:$PATH"
export LDFLAGS="$LDFLAGS -L/opt/homebrew/opt/tcl-tk/lib"
export CPPFLAGS="$CPPFLAGS -I/opt/homebrew/opt/tcl-tk/include"
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/opt/homebrew/opt/tcl-tk/lib/pkgconfig"
# カレントディレクトリ名とユーザー名を表示
PS1='\u \W\$ '

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
