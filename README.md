# AWS Infrastructure Learning Lab

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-%231A1918.svg?style=for-the-badge&logo=ansible&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-%232496ED.svg?style=for-the-badge&logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-%23326CE5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)

AWS上にWebアプリケーション基盤を構築し、構築手順、依存関係、運用、監視、削除までを確認するための学習用リポジトリです。

AWS CLIとShell Scriptでインフラ構築順序を確認し、その上にAnsibleでRailsアプリケーションをデプロイし、CloudWatchでログ収集・監視を追加します。現在は、同じ構成をTerraformへ段階的に移行しています。

詳細な学習方針、参考資料、扱っている構成一覧は [Project Overview](./docs/Project_Overview.md) を参照してください。

## Network Architecture

このラボの論理構成図です。詳細なパラメータ設定については [設計仕様書](./docs/Design_Specification.md) を参照してください。

![Network Architecture](./docs/Network_Architecture.png?v=4)

## Repository Structure

| Directory | 内容 |
| :--- | :--- |
| [`01-aws-cli`](./01-aws-cli/README.md) | AWS CLIとShell Scriptによるインフラ構築 |
| [`02-ansible`](./02-ansible/README.md) | EC2内部設定、Rails 7.2アプリケーションデプロイ |
| [`03-cloudwatch`](./03-cloudwatch/README.md) | CloudWatch Logs、Alarm、Dashboard |
| [`04-terraform`](./04-terraform/README.md) | AWS CLIで作成した構成のTerraform化 |
| [`docs`](./docs) | 設計書、運用設計、トラブルシューティング、構成図 |
| [`dotfiles`](./dotfiles) | 作業環境用dotfiles |

## 01 AWS CLI

AWS CLIで各AWSリソースを順番に作成し、ネットワーク、サーバー、ロードバランサー、データベース、ストレージ、DNS、証明書、メール、キャッシュの構成を確認します。

主な内容:

- VPC / Subnet / Internet Gateway / NAT Gateway
- Route Table / Security Group
- Bastion EC2 / Web EC2
- ALB / Target Group / Listener
- RDS for MySQL
- S3 / IAM Role
- Route 53 Public DNS / Private DNS
- ACM / SES / ElastiCache
- 構築確認、削除、コスト確認

Links:

- [AWS CLI編 README](./01-aws-cli/README.md)
- [初期設定](./01-aws-cli/notes/00_aws_cli_initial_setup.md)
- [解説メモ](./01-aws-cli/notes)
- [シェルスクリプト](./01-aws-cli/scripts)

## 02 Ansible

Ansibleを使って、Private Subnet上のWeb EC2へRails 7.2アプリケーションをデプロイします。

Macから踏み台サーバー経由で `web01` / `web02` に接続し、nginx、Puma、Ruby、Rails、CloudWatch Agentなどを構成します。

確認済み項目:

- Bastion経由のAnsible接続
- Ruby 3.3.6 / Rails 7.2.3
- nginx + Puma + systemd
- ALB + ACM + Route 53によるHTTPS公開
- RDS MySQL接続
- Active StorageによるS3画像保存
- web01 / web02 2台構成での `SECRET_KEY_BASE` 共有
- AnsibleまとめPlaybook `site.yml`

Links:

- [Ansible編 README](./02-ansible/README.md)
- [Inventory](./02-ansible/inventory/hosts.ini)
- [Playbooks](./02-ansible/playbooks)
- [Ansible Reference](./02-ansible/notes/00_ansible_reference.md)

## 03 CloudWatch

CloudWatch Logs、メトリクス、アラーム、ダッシュボードを設定します。

CloudWatch Agentでnginx / PumaログをCloudWatch Logsへ集約し、EC2、ALB、Target Group、RDS、ElastiCacheの主要メトリクスに対してAlarmとDashboardを作成しました。

確認済み項目:

- nginx access/error log収集
- Puma stdout/stderr log収集
- Log Group保持期間7日
- EC2 CPU / StatusCheck Alarm
- ALB 5xx Alarm
- Target Group HealthyHostCount Alarm
- RDS CPU / FreeStorageSpace / DatabaseConnections Alarm
- ElastiCache CPU / CurrConnections Alarm
- CloudWatch Dashboard `nobu-iac-lab-dashboard`

Links:

- [CloudWatch編 README](./03-cloudwatch/README.md)
- [CloudWatch AWS CLI Reference](./03-cloudwatch/notes/00_cloudwatch_aws_cli_reference.md)
- [CloudWatch Logs設計メモ](./03-cloudwatch/notes/01_cloudwatch_logs_setup.md)
- [CloudWatch Dashboard設計メモ](./03-cloudwatch/notes/02_cloudwatch_dashboard_setup.md)
- [CloudWatch scripts](./03-cloudwatch/scripts)

## 04 Terraform

AWS CLIで作成した構成をTerraformで再現します。

現在はTerraform化計画を作成し、まずはVPC、Public / Private Subnet、Internet Gateway、Public Route Tableから段階的に進めています。

最初のTerraform化対象:

- VPC
- Public Subnet x2
- Private Subnet x2
- Internet Gateway
- Public Route Table
- Public Route Table Association

確認済み項目:

- `terraform init`
- `terraform fmt`
- `terraform validate`
- `terraform plan`
- `terraform apply`
- `terraform destroy`
- VPC / Subnet / Internet Gateway / Public Route Tableの作成と削除

Links:

- [Terraform編 README](./04-terraform/README.md)
- [Terraform化計画](./04-terraform/notes/00_terraform_plan.md)
- [VPC Terraform化メモ](./04-terraform/notes/01_vpc.md)
- [NAT Gateway Terraform化メモ](./04-terraform/notes/02_nat_gateway.md)

## Daily Operation

学習コストを抑えるため、必要なときにAWSリソースを作成し、作業終了後に削除します。

### Startup

AWSリソースを作成します。

```bash
cd /Users/nobu/terraform-iac-lab/01-aws-cli/scripts
./All_Setup.sh
```

AnsibleでRailsアプリケーションとCloudWatch Agentを構成します。

```bash
cd /Users/nobu/terraform-iac-lab/02-ansible
export DB_MASTER_PASSWORD='RDS作成時のパスワード'
export SECRET_KEY_BASE=$(openssl rand -hex 64)
ansible-playbook playbooks/site.yml
```

CloudWatch AlarmとDashboardを作成します。

```bash
cd /Users/nobu/terraform-iac-lab/03-cloudwatch/scripts
./01_create_alarms.sh
./02_create_dashboard.sh
```

主な確認:

```bash
curl -I https://www.nobu-iac-lab.com
```

```bash
aws cloudwatch describe-alarms \
  --profile learning \
  --region ap-northeast-1 \
  --alarm-name-prefix nobu-iac-lab \
  --output table
```

### Cleanup

CloudWatch AlarmとDashboardを削除します。

```bash
cd /Users/nobu/terraform-iac-lab/03-cloudwatch/scripts
./03_cleanup_cloudwatch.sh
```

Log Groupも含めて完全に削除する場合:

```bash
DELETE_LOG_GROUPS=true ./03_cleanup_cloudwatch.sh
```

AWSリソース本体を削除し、残存確認とコスト確認を行います。

```bash
cd /Users/nobu/terraform-iac-lab/01-aws-cli/scripts
./cleanup_all.sh
./check_cleanup.sh
./check_cost.sh
```

`cleanup_all.sh` では、ドメイン登録、Public Hosted Zone、ACM証明書、SES Domain Identity、DKIM/SPF/DMARC、SES SMTP IAM userなど、継続利用するリソースは残します。

## Documents

- [Project Overview](./docs/Project_Overview.md)
- [Design Specification](./docs/Design_Specification.md)
- [Operation Design](./docs/Operation_Design.md)
- [Troubleshooting](./docs/Troubleshooting.md)
- [AWS Commands](./docs/aws_commands.md)
- [Terraform Commands](./docs/terraform_commands.md)
- [SSH config example](./docs/ssh_config.example)

## Roadmap

- Terraform化の継続
- Backup設計とリストアテスト
- 構築後テスト設計
- Auto Scaling Group
- ECS / Fargate
- CI/CD
