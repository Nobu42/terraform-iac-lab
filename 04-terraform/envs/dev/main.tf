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
