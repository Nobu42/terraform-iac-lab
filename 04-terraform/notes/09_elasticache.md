# 09 ElastiCache

このメモでは、TerraformでElastiCache for Redisを作成した内容を整理する。

AWS CLI編では、主に以下に対応する。

```text
19_elasticache_setup.sh
```

## この段階のゴール

Railsアプリケーションから利用するRedisをPrivate Subnet上に作成する。

作成するTerraform resource:

```text
aws_elasticache_subnet_group.redis
aws_elasticache_replication_group.redis
```

ElastiCache追加後の `terraform plan` は以下。

```text
Plan: 64 to add, 0 to change, 0 to destroy.
```

前回のRoute 53 / ACMまでが62リソースだったため、ElastiCache関連2リソースが増えた。

```text
62 + 2 = 64
```

## variables.tf

ElastiCacheの主要パラメータを変数化した。

```hcl
variable "elasticache_replication_group_id" {
  description = "Replication group ID for ElastiCache Redis."
  type        = string
  default     = "sample-elasticache"
}
```

```hcl
variable "elasticache_node_type" {
  description = "Node type for ElastiCache Redis."
  type        = string
  default     = "cache.t3.micro"
}
```

```hcl
variable "elasticache_engine_version" {
  description = "Redis engine version for ElastiCache."
  type        = string
  default     = "7.1"
}
```

## Subnet Group

RedisをPrivate Subnet 01 / 02 に配置するため、Subnet Groupを作成する。

```hcl
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
```

ポイント:

- ElastiCacheはPrivate Subnetに配置する
- Web EC2からのみRedis 6379を許可する
- Security Groupは `sample-sg-elasticache`

## Replication Group

Redis本体としてReplication Groupを作成する。

```hcl
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
```

学習環境では、コストを抑えるため以下にしている。

```text
automatic_failover_enabled = false
multi_az_enabled           = false
num_cache_clusters         = 1
```

本番環境では、Multi-AZや自動フェイルオーバーを検討する。

## Security Groupとの関係

ElastiCache用Security Groupでは、Web EC2からRedis 6379を許可している。

```text
Web Security Group -> ElastiCache Security Group: TCP 6379
```

Terraform resource:

```text
aws_security_group_rule.elasticache_ingress_redis_from_web
```

ElastiCacheをインターネットへ公開しない。

## outputs.tf

Redis接続確認やRails設定に使うため、以下をoutputした。

```hcl
output "elasticache_replication_group_id" {
  description = "ElastiCache Redis replication group ID."
  value       = aws_elasticache_replication_group.redis.id
}
```

```hcl
output "elasticache_primary_endpoint" {
  description = "Primary endpoint address of ElastiCache Redis."
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}
```

```hcl
output "elasticache_port" {
  description = "Port of ElastiCache Redis."
  value       = aws_elasticache_replication_group.redis.port
}
```

## よくあるミス

今回、最初にresource blockを `variables.tf` にも貼ってしまい、以下のエラーになった。

```text
Duplicate resource "aws_elasticache_subnet_group" configuration
Duplicate resource "aws_elasticache_replication_group" configuration
```

原因:

```text
main.tf と variables.tf の両方に同じresourceを書いていた
```

正しい配置:

```text
variables.tf
  variable "elasticache_replication_group_id"
  variable "elasticache_node_type"
  variable "elasticache_engine_version"

main.tf
  resource "aws_elasticache_subnet_group" "redis"
  resource "aws_elasticache_replication_group" "redis"

outputs.tf
  output "elasticache_replication_group_id"
  output "elasticache_primary_endpoint"
  output "elasticache_port"
```

## 確認観点

`terraform plan` で見るポイント:

- ElastiCache Subnet GroupがPrivate Subnetを参照している
- Redisのportが6379である
- Security Groupが `aws_security_group.elasticache.id` である
- outputにPrimary Endpointが追加されている

## コスト注意

ElastiCacheは課金対象である。

学習後は不要なら `terraform destroy` する。

NAT Gateway、ALB、RDS、ElastiCacheは放置しない。
