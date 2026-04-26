#!/bin/bash
# 1. AWS CLIを使って、Nameタグが "sample-ec2-bastion" のIDを取得
CURRENT_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=sample-ec2-bastion" --query 'Reservations[].Instances[].InstanceId' --output text)

# 2. そのIDを元に、Ubuntu側のDockerからポートを取得
NEW_PORT=$(ssh nobu@192.168.40.100 "docker ps" | grep "$CURRENT_ID" | sed -E 's/.*:([0-9]+)->22.*/\1/')

if [ -n "$NEW_PORT" ]; then
    sed -i '' -e "/Host bastion/,/Port/ s/Port [0-9]*/Port $NEW_PORT/" ~/.ssh/config
    echo " Success! Config updated to Port $NEW_PORT (ID: $CURRENT_ID)"
else
    echo " Error: Could not find port for ID $CURRENT_ID"
fi
