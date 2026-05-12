# ============================================================
# VPC / Subnet
# ============================================================

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

# ============================================================
# Internet Gateway / Public Route Table
# ============================================================

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

# ============================================================
# NAT Gateway / Private Route Table
# ============================================================

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

# ============================================================
# Security Group
# ============================================================

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

# ============================================================
# EC2 Key Pair / AMI
# ============================================================

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

# ============================================================
# IAM Role / Instance Profile
# ============================================================

# Web EC2用IAM Role.
# EC2がS3やCloudWatch Logsへアクセスするために利用する。
resource "aws_iam_role" "web" {
  name = "sample-role-web"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "sample-role-web"
  })
}

# Web EC2用Instance Profile.
# EC2にIAM Roleを付与するための入れ物。
# aws_instanceではIAM Role名ではなくInstance Profile名を指定する。
resource "aws_iam_instance_profile" "web" {
  name = "sample-instance-profile-web"
  role = aws_iam_role.web.name

  tags = merge(local.common_tags, {
    Name = "sample-instance-profile-web"
  })
}

# Web EC2にS3アクセス権限を付与する。
# Rails Active StorageでS3へ画像を保存するために利用する。
# 学習環境ではAWS管理ポリシー AmazonS3FullAccess を利用する。
resource "aws_iam_role_policy_attachment" "web_s3" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Web EC2にCloudWatch Agent用の権限を付与する。
# nginx / PumaログをCloudWatch Logsへ送信するために利用する。
resource "aws_iam_role_policy_attachment" "web_cloudwatch_agent" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Web EC2にSSM接続用の権限を付与する。
# Session Managerを使った接続や、将来的な運用確認に備えて付与する。
resource "aws_iam_role_policy_attachment" "web_ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ============================================================
# EC2
# ============================================================

# Bastion EC2.
# Public Subnet 01に配置し、管理者がSSHで接続する踏み台サーバーとして利用する。
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_01.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = true

  tags = merge(local.common_tags, {
    Name = "sample-ec2-bastion"
  })
}

# Web EC2 01.
# Private Subnet 01に配置し、ALBからのHTTP 3000とBastionからのSSHを受ける。
resource "aws_instance" "web_01" {
  ami                         = local.web_ami_id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private_01.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.main.key_name
  iam_instance_profile        = aws_iam_instance_profile.web.name
  associate_public_ip_address = false

  tags = merge(local.common_tags, {
    Name = "sample-ec2-web01"
  })
}

# Web EC2 02.
# Private Subnet 02に配置し、ALBからのHTTP 3000とBastionからのSSHを受ける。
resource "aws_instance" "web_02" {
  ami                         = local.web_ami_id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private_02.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.main.key_name
  iam_instance_profile        = aws_iam_instance_profile.web.name
  associate_public_ip_address = false

  tags = merge(local.common_tags, {
    Name = "sample-ec2-web02"
  })
}

# ============================================================
# ALB / Target Group
# ============================================================

# ALB Target Group.
# ALBがWeb EC2へHTTP 3000で転送するためのTarget Group。
resource "aws_lb_target_group" "web" {
  name        = "sample-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = merge(local.common_tags, {
    Name = "sample-tg"
  })
}

# Application Load Balancer.
# Public Subnet 01 / 02 に配置し、インターネットからのHTTPアクセスを受ける。
resource "aws_lb" "web" {
  name               = "sample-elb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.elb.id]
  subnets = [
    aws_subnet.public_01.id,
    aws_subnet.public_02.id
  ]

  tags = merge(local.common_tags, {
    Name = "sample-elb"
  })
}

# ALB HTTP Listener.
# HTTP 80で受けた通信はHTTPS 443へリダイレクトする。
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ALB HTTPS Listener.
# HTTPS 443で受けた通信をTarget Groupへ転送する。
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.aws_acm_certificate.app.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}


# Web EC2 01をTarget Groupへ登録する。
resource "aws_lb_target_group_attachment" "web_01" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_01.id
  port             = 3000
}

# Web EC2 02をTarget Groupへ登録する。
resource "aws_lb_target_group_attachment" "web_02" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_02.id
  port             = 3000
}

# ============================================================
# RDS
# ============================================================

# RDS用DB Subnet Group.
# RDSをPrivate Subnet 01 / 02 に配置するために利用する。
resource "aws_db_subnet_group" "main" {
  name = "sample-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_01.id,
    aws_subnet.private_02.id
  ]

  tags = merge(local.common_tags, {
    Name = "sample-db-subnet-group"
  })
}

# RDS MySQL用Parameter Group.
# 文字コードなど、MySQLの動作パラメータを管理する。
resource "aws_db_parameter_group" "mysql" {
  name   = "sample-db-parameter-group"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }

  tags = merge(local.common_tags, {
    Name = "sample-db-parameter-group"
  })
}

# RDS MySQL用Option Group.
# MySQLでは追加オプションを使わないが、AWS CLI版と対応させるため明示的に作成する。
resource "aws_db_option_group" "mysql" {
  name                 = "sample-db-option-group"
  engine_name          = "mysql"
  major_engine_version = "8.0"

  tags = merge(local.common_tags, {
    Name = "sample-db-option-group"
  })
}

# RDS MySQL Instance.
# Railsアプリケーションが利用するMySQLデータベース。
resource "aws_db_instance" "main" {
  identifier = "sample-db"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = false

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.mysql.name
  option_group_name      = aws_db_option_group.mysql.name
  vpc_security_group_ids = [aws_security_group.db.id]

  publicly_accessible = false
  multi_az            = false

  backup_retention_period = 1
  backup_window           = "18:00-18:30"
  maintenance_window      = "sun:19:00-sun:19:30"

  skip_final_snapshot = true
  deletion_protection = false

  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = merge(local.common_tags, {
    Name = "sample-db"
  })
}

# ============================================================
# S3
# ============================================================

# Rails Active Storage用S3 Bucket.
# 投稿画像など、Railsアプリケーションからアップロードされるファイルを保存する。
resource "aws_s3_bucket" "upload" {
  bucket = var.upload_bucket_name

  tags = merge(local.common_tags, {
    Name = var.upload_bucket_name
  })
}

# S3 Bucketの所有者設定.
# オブジェクト所有権をBucket所有者に寄せ、ACLに依存しない構成にする。
resource "aws_s3_bucket_ownership_controls" "upload" {
  bucket = aws_s3_bucket.upload.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# S3 BucketのPublic Access Block.
# RailsアプリからのアップロードはIAM Role経由で行い、Bucket自体は公開しない。
resource "aws_s3_bucket_public_access_block" "upload" {
  bucket = aws_s3_bucket.upload.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucketの暗号化設定.
# S3管理キー(SSE-S3)でサーバーサイド暗号化を有効にする。
resource "aws_s3_bucket_server_side_encryption_configuration" "upload" {
  bucket = aws_s3_bucket.upload.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucketのバージョニング設定.
# 学習環境ではコストを抑えるため無効にする。
resource "aws_s3_bucket_versioning" "upload" {
  bucket = aws_s3_bucket.upload.id

  versioning_configuration {
    status = "Suspended"
  }
}

# ============================================================
# Route 53 / ACM
# ============================================================

# 既存のPublic Hosted Zoneを参照する。
# Hosted Zone自体は既に作成済みのため、Terraformでは新規作成しない。
data "aws_route53_zone" "public" {
  name         = var.domain_name
  private_zone = false
}

# 既存のACM証明書を参照する。
# ALBでHTTPS Listenerを作るために利用する。
# ACM証明書はALBと同じリージョン(ap-northeast-1)に存在する必要がある。
data "aws_acm_certificate" "app" {
  domain      = var.app_domain_name
  statuses    = ["ISSUED"]
  most_recent = true
}

# www.nobu-iac-lab.com をALBへ向けるAlias Record.
# ALBのDNS名とZone IDを使ってRoute 53 Aliasを作成する。
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = var.app_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.web.dns_name
    zone_id                = aws_lb.web.zone_id
    evaluate_target_health = false
  }
}

# ============================================================
# ElastiCache
# ============================================================

# ElastiCache用Subnet Group.
# RedisをPrivate Subnet 01 / 02 に配置するために利用する。
resource "aws_elasticache_subnet_group" "redis" {
  name = "sample-elasticache-sg"

  subnet_ids = [
    aws_subnet.private_01.id,
    aws_subnet.private_02.id
  ]

  tags = merge(local.common_tags, {
    Name = "sample-elasticache-sg"
  })
}

# ElastiCache Redis Replication Group.
# RailsアプリケーションからRedisとして利用する。
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = var.elasticache_replication_group_id
  description          = "Redis replication group for nobu-iac-lab"

  engine         = "redis"
  engine_version = var.elasticache_engine_version
  node_type      = var.elasticache_node_type

  port = 6379

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.elasticache.id]

  automatic_failover_enabled = false
  multi_az_enabled           = false

  num_cache_clusters = 1

  at_rest_encryption_enabled = false
  transit_encryption_enabled = false

  apply_immediately = true

  tags = merge(local.common_tags, {
    Name = var.elasticache_replication_group_id
  })
}

