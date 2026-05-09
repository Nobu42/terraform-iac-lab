# 変数の定義

variable "aws_profile" {
  description = "AWS CLI profile used by Terraform."
  type        = string
  default     = "learning"
}

variable "aws_region" {
  description = "AWS region used by this lab."
  type        = string
  default     = "ap-northeast-1"
}

variable "vpc_cider" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}
