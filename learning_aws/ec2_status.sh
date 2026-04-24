#!/bin/bash
echo "--- EC2 Instances Status ---"
aws ec2 describe-instances --query 'Reservations[*].Instances[*].{ID:InstanceId,Type:InstanceType,IP:PublicIpAddress,Status:State.Name,Name:Tags[?Key==`Name`].Value | [0]}' --output table

echo "--- Running Containers (LocalStack) ---"
docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Ports}}"
