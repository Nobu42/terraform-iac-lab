#!/bin/bash
echo "--- EC2 Instances Status ---"
aws ec2 describe-instances --query 'Reservations[*].Instances[*].{ID:InstanceId,Type:InstanceType,IP:PublicIpAddress,Status:State.Name,Name:Tags[?Key==`Name`].Value | [0]}' --output table

echo "--- Running Containers (LocalStack) ---"
docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Ports}}"

# 全てのVPCのIDと名前、CIDRを一覧で表示（表形式）
aws ec2 describe-vpcs --query 'Vpcs[*].{ID:VpcId, Name:Tags[?Key==`Name`].Value | [0], CIDR:CidrBlock}' --output table

aws ec2 describe-subnets \
    --filters Name=vpc-id,Values=$VPC_ID \
    --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value | [0], AZ:AvailabilityZone, CIDR:CidrBlock, ID:SubnetId}' \
    --output table

aws ec2 describe-internet-gateways \
    --internet-gateway-ids $IGW_ID \
    --query 'InternetGateways[0].Attachments[0].State' \
    --output text

aws ec2 describe-nat-gateways \
    --query 'NatGateways[*].{Name:Tags[?Key==`Name`].Value | [0], State:State, Subnet:SubnetId, PublicIP:NatGatewayAddresses[0].PublicIp}' \
    --output table

aws ec2 describe-route-tables \
    --route-table-ids $RT_PUB_ID \
    --query 'RouteTables[0].Routes' \
    --output table

aws ec2 describe-route-tables \
    --filters Name=vpc-id,Values=$VPC_ID \
    --query 'RouteTables[*].{Name:Tags[?Key==`Name`].Value | [0], Routes:Routes[?DestinationCidrBlock==`0.0.0.0/0`].[GatewayId,NatGatewayId] | [0]}' \
    --output table

aws ec2 describe-security-groups \
    --group-ids $SG_BASTION_ID $SG_ELB_ID \
    --query 'SecurityGroups[*].{Name:GroupName, Rules:IpPermissions[*].{Port:FromPort, Range:IpRanges[0].CidrIp}}' \
    --output table

aws ec2 describe-instances \
    --instance-ids $BASTION_ID \
    --query 'Reservations[0].Instances[0].{Status:State.Name, PublicIP:PublicIpAddress}' \
    --output table

# インスタンス名とポート番号だけを綺麗に表示
docker ps --filter "name=localstack-ec2" --format "table {{.Names}}\t{{.Ports}}"
