# LocalStack 対応AMI 作成

# ステップ1：Packerテンプレート（HCL）の作成

まず、dotfiles/ ディレクトリ等に amazon-linux-2.pkr.hcl を作成する。
ここで amazonlinux:2 のDockerイメージをベースに指定する。
```
# amazon-linux-2.pkr.hcl
packer {
  required_plugins {
    docker = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "amazon-linux" {
  image  = "amazonlinux:2"
  commit = true
}

build {
  sources = ["source.docker.amazon-linux"]

  # ここで yum を使って必要なものをインストール
  provisioner "shell" {
    inline = [
      "yum update -y",
      "yum install -y yum-utils shadow-utils", # 基本ツール
      "yum install -y mysql",                 # MySQLクライアント
      "yum install -y tar gzip git",          # Railsデプロイに必要
      "echo 'Custom AMI with yum and mysql' > /etc/ami-info"
    ]
  }

  # 作成したコンテナをLocalStackが読み込める形式で保存する設定
  post-processor "docker-tag" {
    repository = "custom-amazon-linux"
    tag        = ["latest"]
  }
}
```

## ステップ2：Packerでイメージをビルド

ターミナルでビルドを実行します。これにより、yumがインストール済みのDockerイメージがローカルに生成される。

```
# ビルド実行
packer init .
packer build amazon-linux-2.pkr.hcl
```
## ステップ3：LocalStackにAMIとして登録する

### 作成したイメージのIDを確認
```
docker images custom-amazon-linux
```

### LocalStackにAMIを登録
```
# AMIとして登録（LocalStack特有の作法）
aws --endpoint-url=http://localhost:4566 ec2 register-image \
    --name "custom-yum-ami" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={SnapshotId=snap-12345}" \
    --architecture x86_64 \
    --root-device-name /dev/sda1
```
