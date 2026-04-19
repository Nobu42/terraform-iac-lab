# Terraform Workspace コマンド集（Horiuchi Lab 運用ガイド）

## 💡 基本コンセプト
同じコード（.tfファイル）を使いながら、Ubuntu用とMac用で**「管理台帳（Stateファイル）」を物理的に分離**して運用します。これにより、環境が混ざる事故を防ぎます。

---
```
## 1. 環境を新しく作る（初回のみ）
新しい作業場所（環境）を追加する時に実行します。

# Ubuntu（自宅サーバー）用の台帳を作成
terraform workspace new ubuntu

# Mac（外出先/Docker）用の台帳を作成
terraform workspace new mac
```
---

## 2. 環境を切り替える（作業場所を変えた時）
場所を移動したら、まず最初にこれを叩いて「台帳」を切り替えます。
```
# 自宅（Ubuntu）で作業を始める時
terraform workspace select ubuntu

# 外出先（Mac）で作業を始める時
terraform workspace select mac
```
---

## 3. 現在の状態を確認する
「今、どっちの台帳を使ってるんだっけ？」と不安になった時に。
```
# Workspaceの一覧を表示（現在の環境に * が付く）
terraform workspace list

# 現在使用中のWorkspace名だけを表示
terraform workspace show
```
---

## 4. 基本のワークフロー
作業時のルーティンです。
```
1. 作業場所に合わせたWorkspaceを選択
   terraform workspace select <ubuntu or mac>

2. 実行計画を確認（ここで差分が出ないことを確認）
   terraform plan

3. インフラに反映
   terraform apply
```
---

## 📂 補足：台帳（State）の保存場所
Workspaceを使うと、プロジェクト内に以下の構造で台帳が保存されます。
中身が別々に管理されていることを意識すると、理解が深まります！
```
./terraform.tfstate.d/
  ├── ubuntu/
  │    └── terraform.tfstate  # Ubuntu環境の「正解」
  └── mac/
       └── terraform.tfstate  # Mac環境の「正解」
```
