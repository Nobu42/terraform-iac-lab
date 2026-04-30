# LocalStack 対応AMI 作成

## 1. Packerのインストール (UbuntuServer)
```
# HashiCorpのリポジトリを追加
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

# Packerのインストール
sudo apt-get update && sudo apt-get install packer -y
```

## 2. Packerテンプレートの作成

```
# Ubuntuにログイン後
cd ~
mkdir -p packer_build
cd packer_build

# ここでファイルを作成（vi や nano で）
vi amazon-linux-2.pkr.hcl
```

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

  # yumの整備と必要なツールのインストール
  provisioner "shell" {
    inline = [
      "yum update -y",
      "yum install -y yum-utils shadow-utils",
      "yum install -y mysql",                 # MySQLクライアント
      "yum install -y tar gzip git",          # Railsデプロイ用
      "echo 'Custom AMI with yum and mysql' > /etc/ami-info"
    ]
  }

  # LocalStackが参照するDockerイメージ名を指定
  post-processor "docker-tag" {
    repository = "localstack-custom-ami"
    tag        = ["latest"]
  }
}
```

## 3. イメージのビルド
```
# 初期化
packer init .

# ビルド（Dockerイメージの生成）
packer build amazon-linux-2.pkr.hcl
```

## 4. LocalStackへのAMI登録

### 4.1 イメージの確認
```
docker images localstack-custom-ami
```

### 4.2 AMIの登録コマンド
```
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test \
aws --endpoint-url=http://localhost:4566 ec2 register-image \
    --name "custom-yum-ami" \
    --description "My custom Amazon Linux 2 with yum" \
    --image-location "localstack-custom-ami:latest" \
    --architecture x86_64 \
    --root-device-name /dev/sda1 \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={SnapshotId=snap-12345}" \
    --virtualization-type hvm \
    --region ap-northeast-1
```
```
# 登録後の確認コマンド
aws --endpoint-url=http://localhost:4566 ec2 describe-images \
    --owners self \
    --region ap-northeast-1 \
    --query "Images[*].{Name:Name,ImageId:ImageId}" \
    --output table
```

## 5. 登録完了の確認とAMI IDの取得
```
# 登録されたAMIのID（ami-xxxxxxxx）を確認
aws --endpoint-url=http://localhost:4566 ec2 describe-images --owners self
```
このコマンドの出力に含まれる ImageId を、All_Setup.sh 内にある aws ec2 run-instances の
--image-id パラメータに使用すれば、最初から yum が使える状態で起動する。


