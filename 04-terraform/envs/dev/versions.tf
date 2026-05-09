terraform {
  # このTerraformコードを実行するために必要なTerraform本体のバージョン
  required_version = ">= 1.6.0"

  # このTerraform構成で利用するProviderを定義する.
  required_providers {
    aws = {
      # hashicorp/aws は HashiCorp公式のAWS Provider を意味する。
      source = "hashicorp/aws"

      # AWS Provider のバージョン制約。
      #   5.0.0 以上 6.0.0 未満
      version = "~> 5.0"
    }
  }
}
