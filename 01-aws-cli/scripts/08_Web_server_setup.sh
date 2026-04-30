#!/bin/bash
set -euo pipefail

PROFILE="learning"
REGION="ap-northeast-1"

VPC_NAME="sample-vpc"
PRIVATE_SUBNET_01_NAME="sample-subnet-private01"
PRIVATE_SUBNET_02_NAME="sample-subnet-private02"
BASTION_INSTANCE_NAME="sample-ec2-bastion"
BASTION_SG_NAME="sample-sg-bastion"
ELB_SG_NAME="sample-sg-elb"
WEB_SG_NAME="sample-sg-web"

KEY_NAME="nobu"
KEY_FILE="${KEY_NAME}.pem"
INSTANCE_TYPE="t3.micro"
WEB01_NAME="sample-ec2-web01"
WEB02_NAME="sample-ec2-web02"
APP_PORT="3000"

# LocalStack向け設定が残っていても実AWSへ向ける
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

# Amazon Linux 2023 latest AMI
AMI_ID=$(aws ssm get-parameter \
  --profile "$PROFILE" \
  --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' \
  --output text)

get_required_id() {
  local label="$1"
  local value="$2"

  if [ "$value" = "None" ] || [ -z "$value" ]; then
    echo "Error: $label not found. Please check previous setup scripts."
    exit 1
  fi

  echo "$value"
}

echo "=== Caller Identity ==="
aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "=== Get Resource IDs ==="
VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text)
VPC_ID=$(get_required_id "VPC" "$VPC_ID")

PRI01_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$PRIVATE_SUBNET_01_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)
PRI01_ID=$(get_required_id "Private Subnet 01" "$PRI01_ID")

PRI02_ID=$(aws ec2 describe-subnets \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$PRIVATE_SUBNET_02_NAME" \
  --query 'Subnets[0].SubnetId' \
  --output text)
PRI02_ID=$(get_required_id "Private Subnet 02" "$PRI02_ID")

BASTION_ID=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$BASTION_INSTANCE_NAME" Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)
BASTION_ID=$(get_required_id "Bastion Instance" "$BASTION_ID")

BASTION_PUBLIC_IP=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$BASTION_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)
BASTION_PUBLIC_IP=$(get_required_id "Bastion Public IP" "$BASTION_PUBLIC_IP")

BASTION_SG_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$BASTION_SG_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)
BASTION_SG_ID=$(get_required_id "Bastion Security Group" "$BASTION_SG_ID")

ELB_SG_ID=$(aws ec2 describe-security-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$ELB_SG_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)
ELB_SG_ID=$(get_required_id "ELB Security Group" "$ELB_SG_ID")

echo "VPC: $VPC_ID"
echo "Private Subnet 01: $PRI01_ID"
echo "Private Subnet 02: $PRI02_ID"
echo "Bastion Instance: $BASTION_ID"
echo "Bastion Public IP: $BASTION_PUBLIC_IP"
echo "Bastion Security Group: $BASTION_SG_ID"
echo "ELB Security Group: $ELB_SG_ID"
echo "AMI: $AMI_ID"

echo "=== Create Web Security Group ==="
WEB_SG_ID=$(aws ec2 create-security-group \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-name "$WEB_SG_NAME" \
  --description "for web servers" \
  --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$WEB_SG_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id "$WEB_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,UserIdGroupPairs=[{GroupId=$BASTION_SG_ID,Description='SSH from bastion'}]"

aws ec2 authorize-security-group-ingress \
  --profile "$PROFILE" \
  --region "$REGION" \
  --group-id "$WEB_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=$APP_PORT,ToPort=$APP_PORT,UserIdGroupPairs=[{GroupId=$ELB_SG_ID,Description='Application traffic from ALB'}]"

echo "Web Security Group: $WEB_SG_ID"

echo "=== Launch Web Servers ==="
WEB01_ID=$(aws ec2 run-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$WEB_SG_ID" \
  --subnet-id "$PRI01_ID" \
  --no-associate-public-ip-address \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$WEB01_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
  --query 'Instances[0].InstanceId' \
  --output text)

WEB02_ID=$(aws ec2 run-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$WEB_SG_ID" \
  --subnet-id "$PRI02_ID" \
  --no-associate-public-ip-address \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$WEB02_NAME},{Key=Project,Value=terraform-iac-lab},{Key=Environment,Value=learning}]" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Created Web01: $WEB01_ID"
echo "Created Web02: $WEB02_ID"

echo "=== Wait for Web Servers to be running ==="
aws ec2 wait instance-running \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$WEB01_ID" "$WEB02_ID"

WEB_INFO=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$WEB01_ID" "$WEB02_ID" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,State.Name,PrivateIpAddress,SubnetId]' \
  --output text)

IP01=$(echo "$WEB_INFO" | awk '$1=="sample-ec2-web01"{print $4}')
IP02=$(echo "$WEB_INFO" | awk '$1=="sample-ec2-web02"{print $4}')

echo "Web01 Private IP: $IP01"
echo "Web02 Private IP: $IP02"

echo "=== SSH Commands via Bastion ==="
echo "ssh -i $KEY_FILE -J ec2-user@$BASTION_PUBLIC_IP ec2-user@$IP01"
echo "ssh -i $KEY_FILE -J ec2-user@$BASTION_PUBLIC_IP ec2-user@$IP02"

echo "=== Describe Web Instances ==="
aws ec2 describe-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --instance-ids "$WEB01_ID" "$WEB02_ID" \
  --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name,Type:InstanceType,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,Subnet:SubnetId}' \
  --output table

echo "=== SSH config block ==="
cat <<EOF
Host bastion
  HostName $BASTION_PUBLIC_IP
  User ec2-user
  IdentityFile $(pwd)/$KEY_FILE
  IdentitiesOnly yes

Host web01
  HostName $IP01
  User ec2-user
  IdentityFile $(pwd)/$KEY_FILE
  IdentitiesOnly yes
  ProxyJump bastion

Host web02
  HostName $IP02
  User ec2-user
  IdentityFile $(pwd)/$KEY_FILE
  IdentitiesOnly yes
  ProxyJump bastion
EOF

