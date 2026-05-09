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

