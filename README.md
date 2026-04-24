# Terraform IaC Lab

MacBook Air (M4) と自宅の Raspberry Pi 4（DNS）、Ubuntu サーバーを連携させ、AWS クラウドインフラをシミュレートする IaC（Infrastructure as Code）学習環境です。

## 目次
- [Network Topology](#network-topology)
- [コンセプト](#コンセプト)
  - [~/.bashrc (環境自動判別)](#bashrc)
  - [~/.vimrc (開発環境設定)](#vimrc)

- [インストールとセットアップ](#インストールとセットアップ)
  - [Mac (Client Side)](#mac-client-side)
  - [Ubuntu Server (LocalStack)](#ubuntu-server-localstack)
  - [Raspberry Pi (CoreDNS)](#raspberry-pi-coredns)

## 学習コンテンツ一覧
- [AWS構築演習 (LocalStack)](./learning_aws/vpc-setup.md) : ネットワークからEC2構築まで
- [Terraform演習](./execises/) : 基本構文からLambda構築まで

## Network Topology

```text
      [ MacBook Air (M4) ] <--- クライアント (外出先 / 自宅)
               |
               | (DNS Query)      (AWS CLI / Terraform)
               |                   |
  +------------v-------------+     | +-------------------------+
  |  Raspberry Pi 4 (DNS)    |     | |  Ubuntu Server (Target) |
  |  (192.168.40.208)        |     | |  (192.168.40.100)       |
  |                          |     | |                         |
  |  [ CoreDNS ]             |     | |  [ LocalStack ]         |
  |  localstack.lab -------- | ----+ |  (AWS Simulation)       |
  +--------------------------+       +-------------------------+
               |                                ^
               |                                |
               +---[ Internal Private Network ]--+
```
## コンセプト
- **ハイブリッド設計:** 自宅の Ubuntu (192.168.40.100) と外出先の Mac を自動判別し、エンドポイントを自動切り替え。

- **最適化された編集環境:** Terraform の自動整形や C/Python の実行環境を Vim に統合。
