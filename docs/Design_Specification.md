# インフラ設計書（AWS VPC構成）

---

## 1. 目的
本設計書は、Webアプリケーション基盤をAWS上に構築するためのネットワークおよびインフラ構成を定義するものである。

---

## 2. システム概要
- パブリックサブネットにALBを配置
- プライベートサブネットにWeb/APサーバを配置
- NAT Gateway経由で外部通信を実施
- RDSはプライベートサブネットに配置（マルチAZ想定）

---

## 3. VPC設計

### 3.1 VPC設定
| 項目 | 設定値 |
| :--- | :--- |
| Name Tag | sample-vpc |
| IPv4 CIDR | 10.0.0.0/16 |
| Tenancy | default |

---

### 3.2 サブネット設計
| 区分 | サブネット名 | AZ | CIDR | 用途 |
| :--- | :--- | :--- | :--- | :--- |
| Public | sample-subnet-public01 | ap-northeast-1a | 10.0.0.0/20 | ALB / NAT配置 |
| Public | sample-subnet-public02 | ap-northeast-1c | 10.0.16.0/20 | ALB / NAT配置 |
| Private | sample-subnet-private01 | ap-northeast-1a | 10.0.64.0/20 | Web/AP |
| Private | sample-subnet-private02 | ap-northeast-1c | 10.0.80.0/20 | Web/AP |

---

### 3.3 インターネット接続
| リソース | 名前 | 接続先 |
| :--- | :--- | :--- |
| IGW | sample-igw | sample-vpc |

---

### 3.4 NAT Gateway
| 名前 | 配置サブネット | AZ | 用途 |
| :--- | :--- | :--- | :--- |
| sample-ngw-01 | sample-subnet-public01 | ap-northeast-1a | Private01用 |
| sample-ngw-02 | sample-subnet-public02 | ap-northeast-1c | Private02用 |

---

### 3.5 ルートテーブル
| 名前 | 対象 | ルート | 関連サブネット |
| :--- | :--- | :--- | :--- |
| sample-rt-public | Public | 0.0.0.0/0 → IGW | public01, public02 |
| sample-rt-private01 | Private | 0.0.0.0/0 → NGW-01 | private01 |
| sample-rt-private02 | Private | 0.0.0.0/0 → NGW-02 | private02 |

---

## 4. セキュリティ設計

### 4.1 セキュリティグループ
| 名前 | 用途 | インバウンド | 備考 |
| :--- | :--- | :--- | :--- |
| sample-sg-bastion | 踏み台 | SSH 22 / 0.0.0.0/0 | 制限検討必要 |
| sample-sg-elb | ALB | HTTP 80 / HTTPS 443 | 公開 |

※ 本番環境ではSSH接続元はIP制限を実施すること

---

## 5. EC2設計

### 5.1 共通設定
| 項目 | 値 |
| :--- | :--- |
| AMI | Amazon Linux 2 |
| インスタンスタイプ | t2.micro |
| 配置 | Private Subnet |
| Public IP | 無効 |
| OSユーザー | ec2-user |

---

### 5.2 サーバ一覧
| 名前 | AZ | サブネット | 用途 |
| :--- | :--- | :--- | :--- |
| sample-ec2-web01 | 1a | private01 | Web/AP |
| sample-ec2-web02 | 1c | private02 | Web/AP |

---

## 6. ロードバランサー設計

### 6.1 ALB
| 項目 | 内容 |
| :--- | :--- |
| 名前 | sample-elb |
| スキーム | internet-facing |
| サブネット | public01, public02 |
| SG | sample-sg-elb |

---

### 6.2 ターゲットグループ
| 項目 | 内容 |
| :--- | :--- |
| 名前 | sample-tg |
| プロトコル | HTTP |
| ポート | 3000 |
| ターゲット | EC2 Webサーバ |
| ヘルスチェック | / |

---

## 7. RDS設計

### 7.1 基本構成
- エンジン: MySQL 8.0
- 配置: Private Subnet
- マルチAZ構成: 有効（想定）

---

### 7.2 パラメータグループ
| 名前 | 内容 |
| :--- | :--- |
| sample-db-pg | mysql8.0 |

---

### 7.3 オプショングループ
| 名前 | 内容 |
| :--- | :--- |
| sample-db-og | mysql 8.0 |

---

### 7.4 サブネットグループ
| 名前 | サブネット |
| :--- | :--- |
| sample-db-subnet | private01, private02 |

---

## 8. 非機能要件

### 可用性
- マルチAZ構成（ALB / EC2 / NAT / RDS）

### セキュリティ
- Private配置による直接アクセス遮断
- SGによる通信制御
- SSHアクセス制限（要検討）

### 運用
- CloudWatchによる監視（別途定義）
- ログ管理（ALB / EC2 / RDS）

---

## 9. 注意事項
- 本設計は検証環境を前提とする
- 本番利用時は以下を追加検討すること
  - WAF導入
  - IAMロール設計
  - バックアップ/DR設計

