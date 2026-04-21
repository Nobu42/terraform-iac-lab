provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    cloudwatch = "http://${var.LOCALSTACK_HOST}:4566"
    dynamodb   = "http://${var.LOCALSTACK_HOST}:4566"
    lambda     = "http://${var.LOCALSTACK_HOST}:4566"
    # S3だけはlocalStackの仕様上、ホスト名解決が必要なためそのままにします。
    s3 = "http://s3.localhost.localstack.cloud:4566"
  }
}

# Macの環境変数 $LOCALSTACK_HOST を受け取るための定義
variable "LOCALSTACK_HOST" {
  type    = string
  default = "localhost"
}

