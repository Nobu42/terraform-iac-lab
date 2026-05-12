# 06 RDS

このメモでは、TerraformでRDS for MySQLを作成するために追加した内容を整理する。

AWS CLI編では、主に以下に対応する。

```text
10_Database_setup.sh
```

## この段階のゴール

Railsアプリケーションが利用するMySQLデータベースをPrivate Subnet上に作成する。

作成するTerraform resource:

```text
aws_db_subnet_group.main
aws_db_parameter_group.mysql
aws_db_option_group.mysql
aws_db_instance.main
```

今回、RDS追加後の `terraform plan` は以下になった。

```text
Plan: 55 to add, 0 to change, 0 to destroy.
```

前回のALBまでが51リソースだったため、RDS関連4リソースが増えた。

```text
51 + 4 = 55
```

## variables.tf

RDSでは、DB名、管理ユーザー名、パスワードを変数化した。

```hcl
variable "db_name" {
  description = "Initial database name for the Rails application."
  type        = string
  default     = "sampleapp"
}
```

```hcl
variable "db_username" {
  description = "Master username for RDS MySQL."
  type        = string
  default     = "adminuser"
}
```

```hcl
variable "db_password" {
  description = "Master password for RDS MySQL."
  type        = string
  sensitive   = true
}
```

`db_password` はGitHubへ書かない。

ローカルの `terraform.tfvars` で渡す。

```hcl
db_password = "your-password"
```

注意点:

- `sensitive = true` にしても、値はTerraform stateに保存される
- `terraform.tfvars` と `terraform.tfstate` はGit管理しない
- `.gitignore` で除外する

## DB Subnet Group

RDSをPrivate Subnet 01 / 02 に配置するため、DB Subnet Groupを作成する。

```hcl
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
```

ポイント:

- RDSはPrivate Subnetに配置する
- Public Subnetには置かない
- 2つのAZのPrivate Subnetを指定する

## Parameter Group

MySQLの文字コード設定をParameter Groupで管理する。

```hcl
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
```

`utf8mb4` は絵文字なども扱える文字コードである。

RailsアプリケーションでMySQLを使うため、文字コードを明示した。

## Option Group

MySQLでは追加オプションを使っていないが、AWS CLI版と対応させるためOption Groupを明示的に作成する。

```hcl
resource "aws_db_option_group" "mysql" {
  name                 = "sample-db-option-group"
  engine_name          = "mysql"
  major_engine_version = "8.0"

  tags = merge(local.common_tags, {
    Name = "sample-db-option-group"
  })
}
```

## RDS Instance

Railsアプリケーションが利用するMySQL DB本体を作成する。

```hcl
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
```

重要な設定:

| 項目 | 意味 |
| :--- | :--- |
| `publicly_accessible = false` | インターネットから直接接続させない |
| `vpc_security_group_ids = [aws_security_group.db.id]` | Web EC2からのMySQL接続だけ許可する |
| `backup_retention_period = 1` | 学習環境として最低限の自動バックアップを保持する |
| `skip_final_snapshot = true` | destroyしやすくするため最終スナップショットを作らない |
| `deletion_protection = false` | 学習環境で削除できるようにする |

本番環境では、`skip_final_snapshot = false` や `deletion_protection = true` を検討する。

## outputs.tf

RDS接続確認やAnsible連携のため、以下をoutputした。

```hcl
output "rds_endpoint" {
  description = "Endpoint address of the RDS MySQL instance."
  value       = aws_db_instance.main.address
}
```

```hcl
output "rds_port" {
  description = "Port of the RDS MySQL instance."
  value       = aws_db_instance.main.port
}
```

```hcl
output "rds_db_name" {
  description = "Initial database name of the RDS MySQL instance."
  value       = aws_db_instance.main.db_name
}
```

```hcl
output "rds_connection_info" {
  description = "RDS connection information for application configuration."
  value       = "${aws_db_instance.main.address}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
}
```

## 確認観点

`terraform plan` で見るポイント:

- RDSがPrivate Subnet用DB Subnet Groupに所属する
- RDSのSecurity Groupが `sample-sg-db` になる
- `publicly_accessible = false` になっている
- DBパスワードを `.tf` に直接書いていない
- outputsにRDS endpointが追加されている

## コスト注意

RDSは課金対象である。

学習後は不要なら `terraform destroy` する。

ただし、削除時にDBデータも消えるため、必要なデータがある場合は事前にバックアップやスナップショットを検討する。
