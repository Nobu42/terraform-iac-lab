# Operation Design

## 目的
このAWS環境を安全に運用・監視・削除するための基本方針を定義する。

## 運用対象
- VPC
- Subnet
- Internet Gateway
- NAT Gateway
- Route Table
- Security Group
- EC2
- ALB
- RDS

## 運用方針
- タグ管理
- 最小権限
- 変更管理
- コスト管理
- バックアップ
- 監視
- 障害対応
- 削除手順

## 監視設計
- EC2 CPU使用率
- ALB 5xx / TargetResponseTime
- RDS CPU / FreeStorageSpace / Connections
- NAT Gateway BytesOutToDestination
- CloudWatch Alarm

## ログ設計
- CloudWatch Logs
- ALB Access Logs
- VPC Flow Logs
- OSログ
- アプリケーションログ

## バックアップ設計
- RDS自動バックアップ
- スナップショット
- 世代管理
- 復旧手順

## セキュリティ運用
- IAM最小権限
- Security Groupレビュー
- SSH接続制限
- Secrets管理
- MFA
- rootユーザー利用禁止

## コスト管理
- AWS Budgets
- NAT Gateway削除確認
- 未使用EIP確認
- 停止忘れEC2確認

## 障害対応
- ALB target unhealthy
- EC2 SSH不可
- RDS接続不可
- NAT Gateway疎通不可

## 定期作業
- 日次
- 週次
- 月次

