#!/bin/bash
set -euo pipefail

PROFILE="learning"
REGION="ap-northeast-1"

DOMAIN_NAME="nobu-iac-lab.com"
DOMAIN_NAME_DOT="${DOMAIN_NAME}."

MAIL_BUCKET_NAME="nobu-iac-lab-mailbox"
MAIL_OBJECT_PREFIX="inbox/"

RULE_SET_NAME="sample-ruleset"
RULE_NAME="sample-rule-inquiry"
RECIPIENT_EMAIL="inquiry@${DOMAIN_NAME}"

MX_RECORD_NAME="${DOMAIN_NAME}"
MX_RECORD_VALUE="10 inbound-smtp.${REGION}.amazonaws.com"

unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST

get_required_value() {
  local label="$1"
  local value="$2"

  if [ "$value" = "None" ] || [ -z "$value" ]; then
    echo "Error: $label not found. Please check previous setup scripts."
    exit 1
  fi

  echo "$value"
}

echo "=== Caller Identity ==="

ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query 'Account' \
  --output text)

ACCOUNT_ID=$(get_required_value "AWS Account ID" "$ACCOUNT_ID")

aws sts get-caller-identity \
  --profile "$PROFILE" \
  --output table

echo "AWS Account ID: $ACCOUNT_ID"

echo "=== Get Public Hosted Zone ID ==="

HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --profile "$PROFILE" \
  --dns-name "$DOMAIN_NAME_DOT" \
  --query "HostedZones[?Name==\`$DOMAIN_NAME_DOT\` && Config.PrivateZone==\`false\`].Id | [0]" \
  --output text)

HOSTED_ZONE_ID=$(get_required_value "Public Hosted Zone" "$HOSTED_ZONE_ID")
HOSTED_ZONE_ID="${HOSTED_ZONE_ID#/hostedzone/}"

echo "Hosted Zone ID: $HOSTED_ZONE_ID"

echo "=== Create S3 Bucket for Received Emails ==="

if aws s3api head-bucket \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$MAIL_BUCKET_NAME" >/dev/null 2>&1; then
  echo "S3 bucket already exists and is accessible: $MAIL_BUCKET_NAME"
else
  echo "Creating S3 bucket: $MAIL_BUCKET_NAME"

  aws s3api create-bucket \
    --profile "$PROFILE" \
    --region "$REGION" \
    --bucket "$MAIL_BUCKET_NAME" \
    --create-bucket-configuration LocationConstraint="$REGION" >/dev/null

  echo "S3 bucket created: $MAIL_BUCKET_NAME"
fi

echo "=== Block Public Access on Mail Bucket ==="

aws s3api put-public-access-block \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$MAIL_BUCKET_NAME" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "=== Disable ACLs on Mail Bucket ==="

aws s3api put-bucket-ownership-controls \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$MAIL_BUCKET_NAME" \
  --ownership-controls '{
    "Rules": [
      {
        "ObjectOwnership": "BucketOwnerEnforced"
      }
    ]
  }'

echo "=== Put S3 Bucket Policy for SES Receiving ==="

SOURCE_ARN="arn:aws:ses:${REGION}:${ACCOUNT_ID}:receipt-rule-set/${RULE_SET_NAME}:receipt-rule/${RULE_NAME}"

BUCKET_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSESPuts",
      "Effect": "Allow",
      "Principal": {
        "Service": "ses.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${MAIL_BUCKET_NAME}/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceAccount": "${ACCOUNT_ID}",
          "AWS:SourceArn": "${SOURCE_ARN}"
        }
      }
    }
  ]
}
EOF
)

aws s3api put-bucket-policy \
  --profile "$PROFILE" \
  --region "$REGION" \
  --bucket "$MAIL_BUCKET_NAME" \
  --policy "$BUCKET_POLICY"

echo "Bucket policy configured for SES."
echo "SES SourceArn: $SOURCE_ARN"

echo "=== Create or Get SES Receipt Rule Set ==="

RULE_SET_EXISTS="true"
aws ses describe-receipt-rule-set \
  --profile "$PROFILE" \
  --region "$REGION" \
  --rule-set-name "$RULE_SET_NAME" >/dev/null 2>&1 || RULE_SET_EXISTS="false"

if [ "$RULE_SET_EXISTS" = "false" ]; then
  echo "Receipt Rule Set not found. Creating: $RULE_SET_NAME"

  aws ses create-receipt-rule-set \
    --profile "$PROFILE" \
    --region "$REGION" \
    --rule-set-name "$RULE_SET_NAME"

  echo "Receipt Rule Set created: $RULE_SET_NAME"
else
  echo "Receipt Rule Set already exists: $RULE_SET_NAME"
fi

echo "=== Create or Update SES Receipt Rule ==="

RECEIPT_RULE_JSON=$(cat <<EOF
{
  "Name": "${RULE_NAME}",
  "Enabled": true,
  "TlsPolicy": "Optional",
  "Recipients": [
    "${RECIPIENT_EMAIL}"
  ],
  "Actions": [
    {
      "S3Action": {
        "BucketName": "${MAIL_BUCKET_NAME}",
        "ObjectKeyPrefix": "${MAIL_OBJECT_PREFIX}"
      }
    }
  ],
  "ScanEnabled": true
}
EOF
)

RULE_EXISTS="true"
aws ses describe-receipt-rule \
  --profile "$PROFILE" \
  --region "$REGION" \
  --rule-set-name "$RULE_SET_NAME" \
  --rule-name "$RULE_NAME" >/dev/null 2>&1 || RULE_EXISTS="false"

if [ "$RULE_EXISTS" = "false" ]; then
  echo "Receipt Rule not found. Creating: $RULE_NAME"

  aws ses create-receipt-rule \
    --profile "$PROFILE" \
    --region "$REGION" \
    --rule-set-name "$RULE_SET_NAME" \
    --rule "$RECEIPT_RULE_JSON"

  echo "Receipt Rule created: $RULE_NAME"
else
  echo "Receipt Rule already exists. Updating: $RULE_NAME"

  aws ses update-receipt-rule \
    --profile "$PROFILE" \
    --region "$REGION" \
    --rule-set-name "$RULE_SET_NAME" \
    --rule "$RECEIPT_RULE_JSON"

  echo "Receipt Rule updated: $RULE_NAME"
fi

echo "=== Activate SES Receipt Rule Set ==="

aws ses set-active-receipt-rule-set \
  --profile "$PROFILE" \
  --region "$REGION" \
  --rule-set-name "$RULE_SET_NAME"

echo "Active Receipt Rule Set: $RULE_SET_NAME"

echo "=== Create / Update MX Record ==="

MX_CHANGE_BATCH=$(cat <<EOF
{
  "Comment": "Create or update MX record for SES email receiving",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${MX_RECORD_NAME}",
        "Type": "MX",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "${MX_RECORD_VALUE}"
          }
        ]
      }
    }
  ]
}
EOF
)

MX_CHANGE_ID=$(aws route53 change-resource-record-sets \
  --profile "$PROFILE" \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "$MX_CHANGE_BATCH" \
  --query 'ChangeInfo.Id' \
  --output text)

MX_CHANGE_ID=$(get_required_value "Route 53 MX Change ID" "$MX_CHANGE_ID")

echo "Route 53 Change ID: $MX_CHANGE_ID"

echo "=== Wait for MX Record to be INSYNC ==="

aws route53 wait resource-record-sets-changed \
  --profile "$PROFILE" \
  --id "$MX_CHANGE_ID"

echo "MX record is INSYNC."

echo "=== Describe SES Receipt Rule Set ==="

aws ses describe-receipt-rule-set \
  --profile "$PROFILE" \
  --region "$REGION" \
  --rule-set-name "$RULE_SET_NAME" \
  --query 'Rules[*].{Name:Name,Enabled:Enabled,Recipients:Recipients,ScanEnabled:ScanEnabled,Actions:Actions[*].S3Action.BucketName}' \
  --output table

echo "=== Describe Active Receipt Rule Set ==="

aws ses describe-active-receipt-rule-set \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query 'Metadata.Name' \
  --output table

echo "=== Describe MX Record ==="

aws route53 list-resource-record-sets \
  --profile "$PROFILE" \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --query "ResourceRecordSets[?Name==\`${DOMAIN_NAME}.\` && Type==\`MX\`]" \
  --output table

echo "------------------------------------------------"
echo "SES receiving setup completed."
echo "Recipient:"
echo "  ${RECIPIENT_EMAIL}"
echo "MX:"
echo "  ${MX_RECORD_VALUE}"
echo "Receipt Rule Set:"
echo "  ${RULE_SET_NAME}"
echo "Receipt Rule:"
echo "  ${RULE_NAME}"
echo "S3 Bucket:"
echo "  s3://${MAIL_BUCKET_NAME}/${MAIL_OBJECT_PREFIX}"
echo "------------------------------------------------"
echo "Test:"
echo "  Send an email to ${RECIPIENT_EMAIL}"
echo "Then check:"
echo "  aws s3 ls s3://${MAIL_BUCKET_NAME}/${MAIL_OBJECT_PREFIX} --profile ${PROFILE}"
echo "------------------------------------------------"

