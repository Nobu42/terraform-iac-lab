# provider の宣言
#
# var はvariables.tfに定義する
#
provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}
