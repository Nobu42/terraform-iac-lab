#!/bin/bash
set -euo pipefail

echo "=== Start all setup scripts ==="

echo "=== Input RDS master password ==="
echo "This password is used by 10_Database_setup.sh."
echo "Input is hidden and will not be displayed."

read -r -s -p "DB master password: " DB_MASTER_PASSWORD
echo

if [ -z "$DB_MASTER_PASSWORD" ]; then
  echo "Error: DB master password is empty."
  exit 1
fi

export DB_MASTER_PASSWORD

./01_vpc_setup.sh
./02_subnet_setup.sh
./03_internetgateway_setup.sh
./04_nat_gateway_setup.sh
./05_route_table_setup.sh
./06_security_group_setup.sh
./07_bastion_server_setup.sh
./08_Web_server_setup.sh
./09_LoadBalancer_setup.sh
./10_Database_setup.sh
./11_s3_setup.sh
./12_public_dns_setup.sh
./14_private_dns_setup.sh
./15_acm_certificate_setup.sh
./18_ses_receiving_setup.sh
./19_elasticache_setup.sh

unset DB_MASTER_PASSWORD

echo "=== All setup completed ==="

