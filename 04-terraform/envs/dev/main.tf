# VPC 本体
resource "aws_vpc" "main" {
  cidr_block          = var.vpc_cidr
  enable_dns_hostname = true
  enable_dns_support  = true

  tags = merge(local.common_tags, {
    Name = "sample-vpc"
  })
}

