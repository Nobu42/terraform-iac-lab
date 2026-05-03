#!/bin/bash
set -euo pipefail

PROFILE="learning"
REGION="ap-northeast-1"

VPC_NAME="sample-vpc"
KEY_NAME="nobu"
KEY_FILE="nobu.pem"

# ALB / Target Group
ALB_NAME="sample-elb"
TARGET_GROUP_NAME="sample-tg"

# RDS
DB_INSTANCE_IDENTIFIER="sample-db"
DB_SUBNET_GROUP_NAME="sample-db-subnet"
DB_PARAMETER_GROUP_NAME="sample-db-pg"
DB_OPTION_GROUP_NAME="sample-db-og"
DB_SG_NAME="sample-sg-db"

# S3 / IAM Role
BUCKET_NAME="nobu-terraform-iac-lab-upload"
ROLE_NAME="sample-role-web"
INSTANCE_PROFILE_NAME="sample-role-web"
POLICY_ARN="arn:aws:iam::aws:policy/AmazonS3FullAccess"

unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

echo "=== Caller Identity ==="
aws sts get-caller-identity --profile "$PROFILE" --output table

echo "=== Get VPC ID ==="
VPC_ID=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "VPC not found. VPC resources may already be deleted."
  VPC_ID=""
else
  echo "Target VPC: $VPC_ID"
fi

echo "=== Delete ALB Listener / Load Balancer / Target Group ==="
LB_ARN=$(aws elbv2 describe-load-balancers \
  --profile "$PROFILE" \
  --region "$REGION" \
  --names "$ALB_NAME" \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text 2>/dev/null || true)

if [ "$LB_ARN" != "None" ] && [ -n "$LB_ARN" ]; then
  LISTENER_ARNS=$(aws elbv2 describe-listeners \
    --profile "$PROFILE" \
    --region "$REGION" \
    --load-balancer-arn "$LB_ARN" \
    --query 'Listeners[].ListenerArn' \
    --output text 2>/dev/null || true)

  for listener_arn in $LISTENER_ARNS; do
    echo "Deleting listener: $listener_arn"
    aws elbv2 delete-listener \
      --profile "$PROFILE" \
      --region "$REGION" \
      --listener-arn "$listener_arn"
  done

  echo "Deleting load balancer: $LB_ARN"
  aws elbv2 delete-load-balancer \
    --profile "$PROFILE" \
    --region "$REGION" \
    --load-balancer-arn "$LB_ARN"

  echo "Waiting for load balancer to be deleted..."
  aws elbv2 wait load-balancers-deleted \
    --profile "$PROFILE" \
    --region "$REGION" \
    --load-balancer-arns "$LB_ARN"
else
  echo "No ALB found."
fi

TG_ARN=$(aws elbv2 describe-target-groups \
  --profile "$PROFILE" \
  --region "$REGION" \
  --names "$TARGET_GROUP_NAME" \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text 2>/dev/null || true)

if [ "$TG_ARN" != "None" ] && [ -n "$TG_ARN" ]; then
  echo "Deleting target group: $TG_ARN"
  aws elbv2 delete-target-group \
    --profile "$PROFILE" \
    --region "$REGION" \
    --target-group-arn "$TG_ARN"
else
  echo "No Target Group found."
fi

echo "=== Delete RDS Instance ==="
DB_STATUS=$(aws rds describe-db-instances \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text 2>/dev/null || true)

if [ "$DB_STATUS" != "None" ] && [ -n "$DB_STATUS" ]; then
  echo "Deleting RDS instance: $DB_INSTANCE_IDENTIFIER"

  aws rds delete-db-instance \
    --profile "$PROFILE" \
    --region "$REGION" \
    --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
    --skip-final-snapshot \
    --delete-automated-backups >/dev/null

  echo "Waiting for RDS instance to be deleted..."
  aws rds wait db-instance-deleted \
    --profile "$PROFILE" \
    --region "$REGION" \
    --db-instance-identifier "$DB_INSTANCE_IDENTIFIER"
else
  echo "No RDS instance found."
fi

echo "=== Delete IAM Instance Profile Associations from EC2 ==="
if [ -n "$VPC_ID" ]; then
  INSTANCE_IDS_FOR_PROFILE=$(aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters \
      Name=vpc-id,Values="$VPC_ID" \
      Name=instance-state-name,Values=pending,running,stopping,stopped \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)

  for instance_id in $INSTANCE_IDS_FOR_PROFILE; do
    ASSOC_ID=$(aws ec2 describe-iam-instance-profile-associations \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filters Name=instance-id,Values="$instance_id" \
      --query 'IamInstanceProfileAssociations[0].AssociationId' \
      --output text 2>/dev/null || true)

    if [ "$ASSOC_ID" != "None" ] && [ -n "$ASSOC_ID" ]; then
      echo "Disassociating IAM Instance Profile from $instance_id: $ASSOC_ID"
      aws ec2 disassociate-iam-instance-profile \
        --profile "$PROFILE" \
        --region "$REGION" \
        --association-id "$ASSOC_ID" >/dev/null
    fi
  done
fi

echo "=== Terminate EC2 Instances ==="
if [ -n "$VPC_ID" ]; then
  INSTANCE_IDS=$(aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters \
      Name=vpc-id,Values="$VPC_ID" \
      Name=instance-state-name,Values=pending,running,stopping,stopped \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)

  if [ -n "$INSTANCE_IDS" ]; then
    echo "Terminating: $INSTANCE_IDS"
    aws ec2 terminate-instances \
      --profile "$PROFILE" \
      --region "$REGION" \
      --instance-ids $INSTANCE_IDS >/dev/null

    aws ec2 wait instance-terminated \
      --profile "$PROFILE" \
      --region "$REGION" \
      --instance-ids $INSTANCE_IDS
  else
    echo "No EC2 instances found."
  fi
else
  echo "Skip EC2 termination because VPC was not found."
fi

echo "=== Delete custom Security Groups ==="
if [ -n "$VPC_ID" ]; then
  for sg_name in sample-sg-db sample-sg-web sample-sg-bastion sample-sg-elb; do
    SG_ID=$(aws ec2 describe-security-groups \
      --profile "$PROFILE" \
      --region "$REGION" \
      --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$sg_name" \
      --query 'SecurityGroups[0].GroupId' \
      --output text 2>/dev/null || true)

    if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
      echo "Deleting SG: $sg_name ($SG_ID)"
      aws ec2 delete-security-group \
        --profile "$PROFILE" \
        --region "$REGION" \
        --group-id "$SG_ID" || echo "Skip: could not delete $sg_name yet"
    fi
  done
fi

echo "=== Delete DB Subnet / Parameter / Option Groups ==="
aws rds delete-db-subnet-group \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" 2>/dev/null || echo "DB Subnet Group already deleted or not found."

aws rds delete-db-parameter-group \
  --profile "$PROFILE" \
  --region "$REGION" \
  --db-parameter-group-name "$DB_PARAMETER_GROUP_NAME" 2>/dev/null || echo "DB Parameter Group already deleted or not found."

aws rds delete-option-group \
  --profile "$PROFILE" \
  --region "$REGION" \
  --option-group-name "$DB_OPTION_GROUP_NAME" 2>/dev/null || echo "DB Option Group already deleted or not found."

echo "=== Delete custom Route Tables ==="
if [ -n "$VPC_ID" ]; then
  RT_IDS=$(aws ec2 describe-route-tables \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" \
    --query 'RouteTables[?Tags[?Key==`Name` && (Value==`sample-rt-public` || Value==`sample-rt-private01` || Value==`sample-rt-private02`)]].RouteTableId' \
    --output text)

  for rt_id in $RT_IDS; do
    ASSOC_IDS=$(aws ec2 describe-route-tables \
      --profile "$PROFILE" \
      --region "$REGION" \
      --route-table-ids "$rt_id" \
      --query 'RouteTables[0].Associations[?Main==`false`].RouteTableAssociationId' \
      --output text)

    for assoc_id in $ASSOC_IDS; do
      echo "Disassociating route table association: $assoc_id"
      aws ec2 disassociate-route-table \
        --profile "$PROFILE" \
        --region "$REGION" \
        --association-id "$assoc_id"
    done

    echo "Deleting route table: $rt_id"
    aws ec2 delete-route-table \
      --profile "$PROFILE" \
      --region "$REGION" \
      --route-table-id "$rt_id"
  done
fi

echo "=== Collect Elastic IP Allocation IDs ==="
ALLOC_IDS=$(aws ec2 describe-addresses \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values=sample-eip-ngw-01,sample-eip-ngw-02 \
  --query 'Addresses[].AllocationId' \
  --output text)

echo "=== Delete NAT Gateways ==="
if [ -n "$VPC_ID" ]; then
  NAT_IDS=$(aws ec2 describe-nat-gateways \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filter Name=vpc-id,Values="$VPC_ID" Name=state,Values=pending,available \
    --query 'NatGateways[].NatGatewayId' \
    --output text)

  if [ -n "$NAT_IDS" ]; then
    for nat_id in $NAT_IDS; do
      echo "Deleting NAT Gateway: $nat_id"
      aws ec2 delete-nat-gateway \
        --profile "$PROFILE" \
        --region "$REGION" \
        --nat-gateway-id "$nat_id" >/dev/null
    done

    echo "Waiting for NAT Gateways to be deleted..."
    aws ec2 wait nat-gateway-deleted \
      --profile "$PROFILE" \
      --region "$REGION" \
      --nat-gateway-ids $NAT_IDS
  else
    echo "No NAT Gateways found."
  fi
fi

echo "=== Release Elastic IPs ==="
for alloc_id in $ALLOC_IDS; do
  echo "Releasing EIP: $alloc_id"
  aws ec2 release-address \
    --profile "$PROFILE" \
    --region "$REGION" \
    --allocation-id "$alloc_id" || echo "Skip: could not release $alloc_id"
done

echo "=== Detach and Delete Internet Gateway ==="
if [ -n "$VPC_ID" ]; then
  IGW_ID=$(aws ec2 describe-internet-gateways \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=attachment.vpc-id,Values="$VPC_ID" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text)

  if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
    echo "Detaching IGW: $IGW_ID"
    aws ec2 detach-internet-gateway \
      --profile "$PROFILE" \
      --region "$REGION" \
      --internet-gateway-id "$IGW_ID" \
      --vpc-id "$VPC_ID"

    echo "Deleting IGW: $IGW_ID"
    aws ec2 delete-internet-gateway \
      --profile "$PROFILE" \
      --region "$REGION" \
      --internet-gateway-id "$IGW_ID"
  fi
fi

echo "=== Delete Subnets ==="
if [ -n "$VPC_ID" ]; then
  SUBNET_IDS=$(aws ec2 describe-subnets \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" \
    --query 'Subnets[].SubnetId' \
    --output text)

  for subnet_id in $SUBNET_IDS; do
    echo "Deleting subnet: $subnet_id"
    aws ec2 delete-subnet \
      --profile "$PROFILE" \
      --region "$REGION" \
      --subnet-id "$subnet_id"
  done
fi

echo "=== Delete Key Pair ==="
aws ec2 delete-key-pair \
  --profile "$PROFILE" \
  --region "$REGION" \
  --key-name "$KEY_NAME" >/dev/null 2>&1 || true

rm -f "$KEY_FILE"

echo "=== Delete VPC ==="
if [ -n "$VPC_ID" ]; then
  aws ec2 delete-vpc \
    --profile "$PROFILE" \
    --region "$REGION" \
    --vpc-id "$VPC_ID"
else
  echo "Skip VPC delete because VPC was not found."
fi

echo "=== Delete S3 Objects and Bucket ==="
if aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$BUCKET_NAME" >/dev/null 2>&1; then

  echo "Deleting objects in S3 bucket: $BUCKET_NAME"
  aws s3 rm "s3://$BUCKET_NAME" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --recursive

  echo "Deleting S3 bucket: $BUCKET_NAME"
  aws s3api delete-bucket \
    --profile "$PROFILE" \
    --region "$REGION" \
    --bucket "$BUCKET_NAME"
else
  echo "S3 bucket not found or not accessible."
fi

echo "=== Delete IAM Role and Instance Profile ==="
aws iam detach-role-policy \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --policy-arn "$POLICY_ARN" 2>/dev/null || echo "Policy already detached or role not found."

aws iam remove-role-from-instance-profile \
  --profile "$PROFILE" \
  --instance-profile-name "$INSTANCE_PROFILE_NAME" \
  --role-name "$ROLE_NAME" 2>/dev/null || echo "Role already removed from Instance Profile or not found."

aws iam delete-instance-profile \
  --profile "$PROFILE" \
  --instance-profile-name "$INSTANCE_PROFILE_NAME" 2>/dev/null || echo "Instance Profile already deleted or not found."

aws iam delete-role \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" 2>/dev/null || echo "IAM Role already deleted or not found."

echo "=== Cleanup completed ==="

