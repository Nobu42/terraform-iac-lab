# VPC設計書

## VPC設定値
- Name Tag: sample-vpc
- IPv4 CIDR: 10.0.0.0/16
- Tenancy: default

---

## サブネット設計一覧
| 区分 | サブネット名 | 可用性ゾーン (AZ) | IPv4 CIDR |
| :--- | :--- | :--- | :--- |
| 外部 (Public) 1 | sample-subnet-public01 | ap-northeast-1a | 10.0.0.0/20 |
| 外部 (Public) 2 | sample-subnet-public02 | ap-northeast-1c | 10.0.16.0/20 |
| 内部 (Private) 1 | sample-subnet-private01 | ap-northeast-1a | 10.0.64.0/20 |
| 内部 (Private) 2 | sample-subnet-private02 | ap-northeast-1c | 10.0.80.0/20 |

---

## インターネットゲートウェイ
- 名前タグ: sample-igw
- VPC: sample-vpc

---

## NATゲートウェイ
| 項目 | NATゲートウェイ 1 | NATゲートウェイ 2 |
| :--- | :--- | :--- |
| 名前 | sample-ngw-01 | sample-ngw-02 |
| サブネット | sample-subnet-public01 | sample-subnet-public02 |
| 接続タイプ | パブリック | パブリック |
| Elastic IP | 自動生成 | 自動生成 |

---

## ルートテーブル設定
| 項目 | パブリック用 (共通) | プライベート用 1 | プライベート用 2 |
| :--- | :--- | :--- | :--- |
| 名前タグ | sample-rt-public | sample-rt-private01 | sample-rt-private02 |
| ルート (local) | 10.0.0.0/16 (local) | 10.0.0.0/16 (local) | 10.0.0.0/16 (local) |
| ルート (外部) | 0.0.0.0/0 (sample-igw) | 0.0.0.0/0 (sample-ngw-01) | 0.0.0.0/0 (sample-ngw-02) |
| 関連付けサブネット | sample-subnet-public01 / sample-subnet-public02 | sample-subnet-private01 | sample-subnet-private02 |

---

## セキュリティグループ設定
| 項目 | 踏み台サーバー用 | ロードバランサー用 |
| :--- | :--- | :--- |
| 名前タグ | sample-sg-bastion | sample-sg-elb |
| 説明 | for bastion server | for load balancer |
| VPC | sample-vpc | sample-vpc |
| インバウンド 1 | SSH (22) / 0.0.0.0/0 | HTTP (80) / 0.0.0.0/0 |
| インバウンド 2 | - | HTTPS (443) / 0.0.0.0/0 |

---

# EC2設計

## 共通設定
| 項目 | 設定内容 |
| :--- | :--- |
| AMI ID | ami-07b643b5e45e (Amazon Linux 2) |
| インスタンスタイプ | t2.micro |
| キーペア | nobu |
| パブリックIP | 無効 |
| セキュリティグループ | default |
| OSユーザー | ec2-user |

## 個別構成
| サーバー名 | 名前タグ | 配置サブネット | 用途 |
| :--- | :--- | :--- | :--- |
| Webサーバー01 | sample-ec2-web01 | sample-subnet-private01 | アプリ実行 (AZ-a) |
| Webサーバー02 | sample-ec2-web02 | sample-subnet-private02 | アプリ実行 (AZ-c) |

---

# ロードバランサー設計

## ALB
| 項目 | 設定内容 |
| :--- | :--- |
| 名前 | sample-elb |
| スキーム | internet-facing |
| タイプ | application |
| サブネット | public01, public02 |
| セキュリティグループ | sample-sg-elb |

## ターゲットグループ
| 項目 | 設定内容 |
| :--- | :--- |
| 名前 | sample-tg |
| プロトコル | HTTP |
| ポート | 3000 |
| ターゲット | sample-ec2-web01, sample-ec2-web02 |
| ヘルスチェック | / |

---

# RDS設計

## 概要
MySQL 8.0 を使用したRDS構築。マルチAZ構成を前提。

---

## パラメータグループ
| 項目 | 設定値 |
| :--- | :--- |
| ファミリー | mysql8.0 |
| 名前 | sample-db-pg |
| 説明 | sample parameter group |

---

## オプショングループ
| 項目 | 設定値 |
| :--- | :--- |
| エンジン | mysql |
| バージョン | 8.0 |
| 名前 | sample-db-og |
| 説明 | sample option group |

---

## DBサブネットグループ
| 項目 | 設定値 |
| :--- | :--- |
| 名前 | sample-db-subnet |
| 説明 | sample db subnet |
| VPC | sample-vpc |
| AZ | ap-northeast-1a, ap-northeast-1c |
| サブネット | sample-subnet-private01, sample-subnet-private02 |

