# terraform apply 後に作成されたIDを見やすく表示するためのファイル
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

