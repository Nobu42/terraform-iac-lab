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

# Terraform や AWS CLI でこのエンドポイントを強制的に使うためのエイリアス
# localstack.lab が名前解決できるか（＝自宅にいるか）を確認
if nslookup localstack.lab > /dev/null 2>&1; then
    # 【自宅モード】
    # DNS が localstack.lab を 192.168.40.100 として解決してくれる
    export LOCALSTACK_HOST=localstack.lab
    export AWS_ENDPOINT_URL="http://localstack.lab:4566"
    echo " Home Lab Mode: localstack.lab connected."
else
    # 【外出先/ローカルモード】
    export LOCALSTACK_HOST=localhost
    export AWS_ENDPOINT_URL="http://localhost:4566"
    echo " Solo Mode: localhost connected."
fi

alias aws='aws --endpoint-url=$AWS_ENDPOINT_URL'
