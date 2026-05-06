# Terraform

## フォルダ構成

```
04-terraform/
  README.md
  notes/
    00_terraform_plan.md
    01_vpc.md
    02_subnet.md
    03_internet_gateway.md
    04_nat_gateway.md
    05_route_table.md
    06_security_group.md
    07_ec2.md
    08_alb.md
    09_rds.md
    10_s3.md
    11_route53_acm.md
    12_elasticache.md
    13_cloudwatch.md
  envs/
    dev/
      main.tf
      variables.tf
      outputs.tf
      terraform.tfvars.example
  modules/
```
## First Step
```
# まずはこれを作成
04-terraform/README.md
04-terraform/notes/00_terraform_plan.md

# どの順番でTerraform化するか決める

# 以下でVPCを作成
envs/dev/provider.tf
envs/dev/variables.tf
envs/dev/main.tf

# 最初にTerraform化するべき対象
VPC
Internet Gateway
Public Subnet x2
Private Subnet x2
Route Table
Route Table Association
```

