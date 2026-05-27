#!/usr/bin/env bash
set -euo pipefail

cd /Users/nobu/terraform-iac-lab/02-ansible

if [ -z "${DB_MASTER_PASSWORD:-}" ]; then
  echo "Error: DB_MASTER_PASSWORD is not set."
  echo "Run: export DB_MASTER_PASSWORD='RDS作成時のパスワード'"
  exit 1
fi

if [ -z "${SECRET_KEY_BASE:-}" ]; then
  export SECRET_KEY_BASE
  SECRET_KEY_BASE=$(openssl rand -hex 64)
fi

ansible-playbook playbooks/site.yml
