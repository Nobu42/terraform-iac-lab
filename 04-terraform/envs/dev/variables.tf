# ============================================================
# AWS Provider
# ============================================================

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

# ============================================================
# VPC / Subnet
# ============================================================

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

# ============================================================
# Security Group
# ============================================================

variable "admin_ip_cidr" {
  description = "CIDR block allowed to SSH to the bastion host. Example: x.x.x.x/32"
  type        = string
}

# ============================================================
# EC2 Key Pair / AMI
# ============================================================

variable "key_pair_name" {
  description = "EC2 key pair name used for SSH."
  type        = string
  default     = "nobu"
}

variable "public_key_path" {
  description = "Path to the public key file registered as EC2 key pair."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "use_custom_web_ami" {
  description = "Whether to use custom AMI for web servers."
  type        = bool
  default     = false
}

variable "custom_web_ami_id" {
  description = "Custom AMI ID for web servers. Used when use_custom_web_ami is true."
  type        = string
  default     = ""
}

# ============================================================
# RDS
# ============================================================

variable "db_name" {
  description = "Initial database name for the Rails application."
  type        = string
  default     = "sampleapp"
}

variable "db_username" {
  description = "Master username for RDS MySQL."
  type        = string
  default     = "adminuser"
}

variable "db_password" {
  description = "Master password for RDS MySQL."
  type        = string
  sensitive   = true
}

# ============================================================
# S3
# ============================================================

variable "upload_bucket_name" {
  description = "S3 bucket name for Rails Active Storage uploads."
  type        = string
  default     = "nobu-terraform-iac-lab-upload"
}

# ============================================================
# Route 53 / ACM
# ============================================================

variable "domain_name" {
  description = "Root domain name managed by Route 53."
  type        = string
  default     = "nobu-iac-lab.com"
}

variable "app_domain_name" {
  description = "Application domain name for ALB."
  type        = string
  default     = "www.nobu-iac-lab.com"
}

# ============================================================
# ElastiCache
# ============================================================

variable "elasticache_replication_group_id" {
  description = "Replication group ID for ElastiCache Redis."
  type        = string
  default     = "sample-elasticache"
}

variable "elasticache_node_type" {
  description = "Node type for ElastiCache Redis."
  type        = string
  default     = "cache.t3.micro"
}

variable "elasticache_engine_version" {
  description = "Redis engine version for ElastiCache."
  type        = string
  default     = "7.1"
}

