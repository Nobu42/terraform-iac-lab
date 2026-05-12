# ============================================================
# Network
# ============================================================

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value = [
    aws_subnet.public_01.id,
    aws_subnet.public_02.id
  ]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value = [
    aws_subnet.private_01.id,
    aws_subnet.private_02.id
  ]
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

# ============================================================
# EC2
# ============================================================

# Bastion EC2のInstance ID.
output "bastion_instance_id" {
  description = "Instance ID of the bastion EC2 instance."
  value       = aws_instance.bastion.id
}

# Bastion EC2のPublic IP.
# SSH接続先として利用する。
output "bastion_public_ip" {
  description = "Public IP address of the bastion EC2 instance."
  value       = aws_instance.bastion.public_ip
}

# Bastion EC2のPrivate IP.
output "bastion_private_ip" {
  description = "Private IP address of the bastion EC2 instance."
  value       = aws_instance.bastion.private_ip
}

# Web EC2 01のInstance ID.
output "web_01_instance_id" {
  description = "Instance ID of web EC2 instance 01."
  value       = aws_instance.web_01.id
}

# Web EC2 01のPrivate IP.
output "web_01_private_ip" {
  description = "Private IP address of web EC2 instance 01."
  value       = aws_instance.web_01.private_ip
}

# Web EC2 02のInstance ID.
output "web_02_instance_id" {
  description = "Instance ID of web EC2 instance 02."
  value       = aws_instance.web_02.id
}

# Web EC2 02のPrivate IP.
output "web_02_private_ip" {
  description = "Private IP address of web EC2 instance 02."
  value       = aws_instance.web_02.private_ip
}

# Web EC2のInstance ID一覧.
# ALB Target Group登録や確認時に利用する。
output "web_instance_ids" {
  description = "Instance IDs of web EC2 instances."
  value = [
    aws_instance.web_01.id,
    aws_instance.web_02.id
  ]
}

# Web EC2のPrivate IP一覧.
# SSH configやPrivate DNS設定の確認に利用する。
output "web_private_ips" {
  description = "Private IP addresses of web EC2 instances."
  value = [
    aws_instance.web_01.private_ip,
    aws_instance.web_02.private_ip
  ]
}

# ============================================================
# ALB / Target Group
# ============================================================

# ALBのDNS名.
# apply後にHTTP疎通確認で利用する。
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.web.dns_name
}

# ALBのARN.
# ListenerやCloudWatch Alarm設定の確認で利用する。
output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.web.arn
}

# ALBのZone ID.
# Route 53 Alias Recordを作成するときに利用する。
output "alb_zone_id" {
  description = "Canonical hosted zone ID of the Application Load Balancer."
  value       = aws_lb.web.zone_id
}

# Target GroupのARN.
# Target Group登録やCloudWatch Alarm設定の確認で利用する。
output "target_group_arn" {
  description = "ARN of the ALB Target Group."
  value       = aws_lb_target_group.web.arn
}

# Target Group名.
output "target_group_name" {
  description = "Name of the ALB Target Group."
  value       = aws_lb_target_group.web.name
}

# ============================================================
# RDS
# ============================================================

# RDSのエンドポイント.
# Railsアプリケーションのdatabase.ymlや接続確認で利用する。
output "rds_endpoint" {
  description = "Endpoint address of the RDS MySQL instance."
  value       = aws_db_instance.main.address
}

# RDSのポート番号.
output "rds_port" {
  description = "Port of the RDS MySQL instance."
  value       = aws_db_instance.main.port
}

# RDSのDB名.
output "rds_db_name" {
  description = "Initial database name of the RDS MySQL instance."
  value       = aws_db_instance.main.db_name
}

# RDSの接続先文字列.
# Ansibleやアプリケーション設定時の確認用。
output "rds_connection_info" {
  description = "RDS connection information for application configuration."
  value       = "${aws_db_instance.main.address}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
}

# ============================================================
# S3
# ============================================================

# Rails Active Storage用S3 Bucket名.
output "upload_bucket_name" {
  description = "S3 bucket name for Rails Active Storage uploads."
  value       = aws_s3_bucket.upload.bucket
}

# Rails Active Storage用S3 Bucket ARN.
output "upload_bucket_arn" {
  description = "ARN of the S3 bucket for Rails Active Storage uploads."
  value       = aws_s3_bucket.upload.arn
}

# ============================================================
# Route 53 / ACM
# ============================================================

# Route 53 Public Hosted Zone ID.
output "public_hosted_zone_id" {
  description = "Route 53 public hosted zone ID."
  value       = data.aws_route53_zone.public.zone_id
}

# アプリケーションURL.
output "app_url" {
  description = "HTTPS URL of the application."
  value       = "https://${var.app_domain_name}"
}

# ACM証明書ARN.
output "acm_certificate_arn" {
  description = "ARN of the ACM certificate used by ALB HTTPS listener."
  value       = data.aws_acm_certificate.app.arn
}

# ============================================================
# ElastiCache
# ============================================================

# ElastiCache Replication Group ID.
output "elasticache_replication_group_id" {
  description = "ElastiCache Redis replication group ID."
  value       = aws_elasticache_replication_group.redis.id
}

# ElastiCache Primary Endpoint.
# RailsアプリケーションのRedis接続先として利用する。
output "elasticache_primary_endpoint" {
  description = "Primary endpoint address of ElastiCache Redis."
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

# ElastiCache Redis Port.
output "elasticache_port" {
  description = "Port of ElastiCache Redis."
  value       = aws_elasticache_replication_group.redis.port
}
