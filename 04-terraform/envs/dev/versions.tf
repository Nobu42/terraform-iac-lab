terraform {
  # このTerraformコードを実行するために必要なTerraform本体のバージョン
  #
  # >= 1.6.0 は「1.6.0以上なら利用」可能という意味。
  # チーム開発や本番環境では、より厳密にバージョンを固定することもあ流らしい。。。
  required_version = ">= 1.6.0"

  # このTerraform構成で利用するProviderを定義する.
  #
  # Providerは、Terraformが外部サービスを操作するためのプラグイン。
  # AWSを操作する場合は hashicorp/aws provider を使う。
  required_providers {
    aws = {
      # AWS Providerの配布元。
      # hashicorp/aws は HashiCorp公式のAWS Provider を意味する。
      source = "hashicorp/aws"

      # AWS Provider のバージョン制約。
      #
      # ~> 5.0 は「5.x系を使う」という意味。
      # 例:
      #   5.0.0 以上
      #   6.0.0 未満
      #
      #   Provider のメジャーバージョンが変わると、
      #   一部リソースの書き方や挙動が変わる可能性があるため、
      #   学習用でもメジャーバージョンは固定しておく。
      version = "~> 5.0"
    }
  }
}
