# VPC 本体
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "sample-vpc"
  })
}

# Public Subnet 01.
resource "aws_subnet" "public_01" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_01_cidr
  availability_zone       = var.availability_zone_1a
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "sample-subnet-public01"
    Type = "public"
  })
}

# Public Subnet 02.
resource "aws_subnet" "public_02" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_02_cidr
  availability_zone       = var.availability_zone_1c
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "sample-subnet-public02"
    Type = "public"
  })
}

# Private Subnet 01.
resource "aws_subnet" "private_01" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_01_cidr
  availability_zone = var.availability_zone_1a

  tags = merge(local.common_tags, {
    Name = "sample-subnet-private01"
    Type = "private"
  })
}

# Private Subnet 02.
resource "aws_subnet" "private_02" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_02_cidr
  availability_zone = var.availability_zone_1c

  tags = merge(local.common_tags, {
    Name = "sample-subnet-private02"
    Type = "private"
  })
}

# Internet Gateway.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "sample-igw"
  })
}

# Public Route table.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "sample-rt-public"
  })
}

# Public SubnetからInternet Gatewayへ出るデフォルトルート.
resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Public Subnet 01 をPublic Route Tableに関連付ける.
resource "aws_route_table_association" "public_01" {
  subnet_id      = aws_subnet.public_01.id
  route_table_id = aws_route_table.public.id
}

# Public Subnet 02 を Public Route Tableに関連付ける.
resource "aws_route_table_association" "public_02" {
  subnet_id      = aws_subnet.public_02.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway用のElastic IP.
resource "aws_eip" "nat_01" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "sample-eip-ngw-01"
  })
}

resource "aws_eip" "nat_02" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "sample-eip-ngw-02"
  })
}

# NAT Gateway
# Private SubnetのEC2がインターネットに出るための出口
# NAT Gateway自体はPublic Subnetに配置する。
resource "aws_nat_gateway" "nat_01" {
  allocation_id = aws_eip.nat_01.id
  subnet_id     = aws_subnet.public_01.id

  tags = merge(local.common_tags, {
    Name = "sample-ngw-01"
  })
}

resource "aws_nat_gateway" "nat_02" {
  allocation_id = aws_eip.nat_02.id
  subnet_id     = aws_subnet.public_02.id

  tags = merge(local.common_tags, {
    Name = "sample-ngw-02"
  })
}

# Private Route Table 01.
# Private Subnet 01 から外部へ出る通信をNAT Gateway 01へ向ける。
resource "aws_route_table" "private_01" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "sample-rt-private01"
  })
}

# Private Route Table 02.
# Private Subnet 02から外部へ出る通信をNAT Gateway 02へ向ける。
resource "aws_route_table" "private_02" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "sample-rt-private02"
  })
}

# Private Subnet 01からインターネット方向へ出るデフォルトルート。
# 宛先 0.0.0.0/0 をNAT Gateway 01 に向ける。
resource "aws_route" "private_01_default" {
  route_table_id         = aws_route_table.private_01.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_01.id
}

# Private Subnet 02からインターネット方向へ出るデフォルトルート。
# 宛先 0.0.0.0/0 をNAT Gateway 02へ向ける。
resource "aws_route" "private_02_default" {
  route_table_id         = aws_route_table.private_02.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_02.id
}

# Private Subnet 01 を Private Route Table 01 に関連付ける。
resource "aws_route_table_association" "private_01" {
  subnet_id      = aws_subnet.private_01.id
  route_table_id = aws_route_table.private_01.id
}

# Private Subnet 02 を Private Route Table 02 に関連付ける。
resource "aws_route_table_association" "private_02" {
  subnet_id      = aws_subnet.private_02.id
  route_table_id = aws_route_table.private_02.id
}

# Bastion用のSecurity Group.
# 管理者がSSHで踏み台サーバーへの接続をするために使う。
resource "aws_security_group" "bastion" {
  name        = "sample-sg-bastion"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "sample-sg-bastion"
  })
}

# ALB用Security Group.
# インターネットからHTTP/HTTPSを受ける。
resource "aws_security_group" "elb" {
  name        = "sample-sg-elb"
  description = "Security group for application load balancer"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "sample-sg-elb"
  })
}

# Web EC2用Security Group.
# ALBからのHTTP通信と、BastionからのSSH通信を受ける。
resource "aws_security_group" "web" {
  name        = "sample-sg-web"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "sample-sg-web"
  })
}

# RDS用のSecurity group
# Web EC2からのMySQL接続を受ける。
resource "aws_security_group" "db" {
  name        = "sample-sg-db"
  description = "Security group for RDS MySQL"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "sample-sg-db"
  })
}

# ElastiCache用Security Group.
# Web EC2からのRedis接続を受ける。
resource "aws_security_group" "elasticache" {
  name        = "sample-sg-elasticache"
  description = "Security group for ElastiCache Redis"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "sample-sg-elasticache"
  })
}

# BastionへのSSHを許可する。
# 許可もとはvariables.tfで定義したadmin_ip_cidrに限定する。
resource "aws_security_group_rule" "bastion_ingress_ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.bastion.id

  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [var.admin_ip_cidr]

  description = "Allow SSH from admin IP"
}

# ALBへのHTTPを許可する。
# HTTPはACM証明書取得後にHTTPSへリダイレクトする想定。
resource "aws_security_group_rule" "elb_ingress_http" {
  type              = "ingress"
  security_group_id = aws_security_group.elb.id

  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  description = "Allow HTTP from internet"
}

# ALBへのHTTPSを許可する。
# 利用者は最終的にHTTPSでRailsアプリへアクセスする。
resource "aws_security_group_rule" "elb_ingress_https" {
  type              = "ingress"
  security_group_id = aws_security_group.elb.id

  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  description = "Allow HTTPS from internet"
}

# Web EC2へのHTTP 3000をALBから許可する。
# ALBのTarget GroupがWeb EC2の3000番へ転送する構成。
resource "aws_security_group_rule" "web_ingress_http_from_elb" {
  type              = "ingress"
  security_group_id = aws_security_group.web.id

  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.elb.id

  description = "Allow HTTP 3000 from ALB"
}

# Web EC2へのSSHをBastionから許可する。
# Private Subnet上のWeb EC2へ直接SSHせず、踏み台経由で接続する。
resource "aws_security_group_rule" "web_ingress_ssh_from_bastion" {
  type              = "ingress"
  security_group_id = aws_security_group.web.id

  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id

  description = "Allow SSH from bastion"
}

# RDS MySQLへの接続をWeb EC2から許可する。
# RailsアプリケーションがRDS MySQLへ接続するためのルール。
resource "aws_security_group_rule" "db_ingress_mysql_from_web" {
  type              = "ingress"
  security_group_id = aws_security_group.db.id

  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id

  description = "Allow MySQL from web servers"
}

# ElastiCache Redisへの接続をWeb EC2から許可する。
# Rails アプリケーションがRedisへ接続するためのルール。
resource "aws_security_group_rule" "elasticache_ingress_redis_from_web" {
  type              = "ingress"
  security_group_id = aws_security_group.elasticache.id

  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id

  description = "Allow Redis from web servers"
}

# Bastionから外部への通信を許可する。
# OSパッケージ更新やSSM、必要な外部通信を妨げないため、学習環境では全Outboundを許可する。
resource "aws_security_group_rule" "bastion_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.bastion.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  description = "Allow all outbound from bastion"
}

# ALBからWeb EC2へのHTTP 3000を許可する。
# ALBはTarget Group経由でWeb EC2の3000番へリクエストを転送する。
resource "aws_security_group_rule" "elb_egress_http_to_web" {
  type              = "egress"
  security_group_id = aws_security_group.elb.id

  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id

  description = "Allow HTTP 3000 to web servers"
}

# Web EC2から外部への通信を許可する
# yum/dnf, Ruby gem, S3, SES, SMTP 外部APIなどへの通信を行うため、学習環境では全Outboundを許可する。
resource "aws_security_group_rule" "web_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.web.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  description = "Allow all outbound from web servers"
}

# RDSから外部への通信を許可する
# RDSは基本的に受け側だが、AWSのデフォルトSecurity Group挙動に合わせて学習環境では全Outboundを明示する。
resource "aws_security_group_rule" "db_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.db.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  description = "Allow all outbound from RDS security group"
}

# ElastiCacheから外部への通信を許可する
# ElastiCacheも基本的に受け側だが、学習環境ではSecurity GroupのOutboundを明示して管理する。
resource "aws_security_group_rule" "elasticache_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.elasticache.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  description = "Allow all outbound from ElastiCache security group"
}

# EC2 Key Pair.
# SSH接続に使うKey PairをAWSへ登録する。
# GitHubへ秘密鍵を上げないため、Terraformでは公開鍵ファイルだけを読み込む。
resource "aws_key_pair" "main" {
  key_name   = var.key_pair_name
  public_key = file(var.public_key_path)

  tags = merge(local.common_tags, {
    Name = var.key_pair_name
  })
}

# Amazon Linux 2023の最新AMIを取得する。
# Bastionは標準のAmazon Linux 2023 AMIから作成する。
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Web EC2で利用するAMIを決める。
# use_custom_web_ami = true の場合は、Rubyやnginxを事前導入したカスタムAMIを使う。
# false の場合は、Amazon Linux 2023の最新AMIを使う。
locals {
  web_ami_id = var.use_custom_web_ami ? var.custom_web_ami_id : data.aws_ami.amazon_linux_2023.id
}
