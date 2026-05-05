#!/bin/bash

cd /Users/nobu/terraform-iac-lab/02-ansible
export DB_MASTER_PASSWORD='Kairage-3660'
export SECRET_KEY_BASE=$(openssl rand -hex 64)
ansible-playbook playbooks/site.yml

