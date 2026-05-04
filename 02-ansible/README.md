# 02 Ansible

このディレクトリでは、Ansibleを使ってPrivate Subnet上のWebサーバーを構成管理します。

AWS CLI編では、VPC、Subnet、EC2、ALB、RDS、S3、Route 53、ACM、SES、ElastiCacheなどのAWSリソースを作成しました。
Ansible編では、作成済みのWebサーバーに対して、パッケージ導入、Ruby/Rails環境構築、アプリケーション配置、サービス起動設定を自動化していきます。

## 目的

- Webサーバー内部の設定をAnsibleで自動化する
- 手作業でのパッケージ導入や設定変更をPlaybook化する
- web01 / web02 に同じ設定を反映できるようにする
- Railsアプリケーションのデプロイ手順を整理する
- 後続のCloudWatch監視、Terraform化、Auto Scaling構成につなげる

## 実行環境

AnsibleはローカルPCから実行する。

```text
Mac
  ↓ Ansible
Bastion
  ↓ ProxyJump
web01 / web02
```

| 項目 | 値 |
| :--- | :--- |
| Ansible実行元 | Mac |
| 接続先 | web01, web02 |
| SSHユーザー | ec2-user |
| 接続経路 | Bastion経由 |
| 対象OS | Amazon Linux 2023 |
| 接続先Python | /usr/bin/python3.9 |

## ディレクトリ構成

```text
02-ansible/
├── README.md
├── group_vars/
├── inventory/
│   └── hosts.ini
└── playbooks/
    └── 01_ping.yml
```

## Inventory

`inventory/hosts.ini` にAnsibleの接続先を定義する。

```ini
[web]
web01
web02

[web:vars]
ansible_user=ec2-user
ansible_ssh_common_args='-o ProxyJump=bastion'
ansible_python_interpreter=/usr/bin/python3.9
```

`web01`、`web02`、`bastion` は `~/.ssh/config` に定義済みであることを前提とする。

## SSH接続確認

Ansibleを実行する前に、通常のSSH接続ができることを確認する。

```bash
ssh web01
ssh web02
```

## Ansibleインストール

MacにAnsibleをインストールする。

```bash
brew install ansible
```

バージョン確認:

```bash
ansible --version
```

## 疎通確認

まずAnsibleのpingモジュールで、web01 / web02 に接続できることを確認する。

```bash
ansible -i inventory/hosts.ini web -m ping
```

Playbookで確認する場合:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/01_ping.yml
```

## 01_ping.yml

```yaml
---
- name: Check connection to web servers
  hosts: web
  gather_facts: false

  tasks:
    - name: Ping web servers
      ansible.builtin.ping:
```

## 実行結果

```text
PLAY [Check connection to web servers]

TASK [Ping web servers]
ok: [web01]
ok: [web02]

PLAY RECAP
web01 : ok=1 changed=0 unreachable=0 failed=0
web02 : ok=1 changed=0 unreachable=0 failed=0
```

この結果により、MacからBastion経由でPrivate Subnet上のWebサーバーへAnsible接続できることを確認した。

## 次にやること

- 共通パッケージのインストール
- Ruby / Rails 実行環境の構築
- Railsアプリケーションの配置
- RDS接続設定
- ElastiCache Redis接続設定
- S3アップロード設定
- SESメール送信設定
- Puma / systemd によるアプリケーション起動設定
- ALB経由の動作確認

