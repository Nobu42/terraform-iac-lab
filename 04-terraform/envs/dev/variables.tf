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

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_01_cidr" {
  description = "CIDR block for public subnet 01."
  type        = string
  default     = "10.0.0.0/20"
}

variable "public_subnet_02_cidr" {
  description = "CIDR block for public subnet 02."
  type        = string
  default     = "10.0.16.0/20"
}

variable "private_subnet_01_cidr" {
  description = "CIDR block for privatesubnet 01."
  type        = string
  default     = "10.0.64.0/20"
}

variable "private_subnet_02_cidr" {
  description = "CIDR block for private subnet 02."
  type        = string
  default     = "10.0.80.0/20"
}

variable "availability_zone_1a" {
  description = "Availability Zone 1a."
  type        = string
  default     = "ap-northeast-1a"
}

variable "availability_zone_1c" {
  description = "Availability Zone 1c."
  type        = string
  default     = "ap-northeast-1c"
}


