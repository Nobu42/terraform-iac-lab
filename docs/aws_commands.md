# AWS CLI コマンド集

AWS CLIで実AWS環境を操作・確認するためのコマンド集です。

このリポジトリでは、AWS CLIによるインフラ構築を通して、VPC、Subnet、Internet Gateway、NAT Gateway、Route Table、Security Group、EC2などの依存関係を確認します。

## 基本方針

このプロジェクトでは、実AWS操作時に以下を明示します。

```bash
--profile learning
--region ap-northeast-1
```

例:

```bash
aws sts get-caller-identity \
  --profile learning \
  --region ap-northeast-1
```

LocalStack用のendpoint設定が残っていると、実AWSではなくLocalStackへ向いてしまうため注意します。

```bash
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST
```

## 1. 認証情報・操作対象の確認

現在どのAWSアカウント、IAMユーザーで操作しているか確認します。

```bash
aws sts get-caller-identity \
  --profile learning \
  --output table
```

期待する形式:

```text
arn:aws:iam::<AWSアカウントID>:user/<IAMユーザー名>
```

`000000000000` や `root` が表示される場合は、LocalStack向きのendpointやaliasが残っている可能性があります。

AWS CLI設定の確認:

```bash
aws configure list --profile learning
```

endpoint設定の確認:

```bash
aws configure get endpoint_url --profile learning
echo $AWS_ENDPOINT_URL
type -a aws
alias aws
```

## 2. リージョン・AZの確認

利用可能なリージョン一覧:

```bash
aws ec2 describe-regions \
  --profile learning \
  --output table
```

東京リージョンのAZ確認:

```bash
aws ec2 describe-availability-zones \
  --profile learning \
  --region ap-northeast-1 \
  --query 'AvailabilityZones[*].{Name:ZoneName,State:State}' \
  --output table
```

## 3. VPCの確認

VPC一覧:

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table
```

`sample-vpc` の確認:

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-vpc \
  --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table
```

## 4. Subnetの確認

VPC配下のSubnet一覧:

```bash
VPC_ID=$(aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-vpc \
  --query 'Vpcs[0].VpcId' \
  --output text)

aws ec2 describe-subnets \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'Subnets[*].{Name:Tags[?Key==`Name`].Value|[0],Type:Tags[?Key==`Type`].Value|[0],AZ:AvailabilityZone,CIDR:CidrBlock,PublicIP:MapPublicIpOnLaunch,ID:SubnetId}' \
  --output table
```

## 5. Internet Gatewayの確認

VPCにアタッチされたInternet Gatewayを確認:

```bash
aws ec2 describe-internet-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=attachment.vpc-id,Values="$VPC_ID" \
  --query 'InternetGateways[*].{ID:InternetGatewayId,Name:Tags[?Key==`Name`].Value|[0],VPC:Attachments[0].VpcId,State:Attachments[0].State}' \
  --output table
```

## 6. NAT Gateway / Elastic IPの確認

NAT Gateway確認:

```bash
aws ec2 describe-nat-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filter Name=tag:Name,Values=sample-ngw-01,sample-ngw-02 \
  --query 'NatGateways[*].{Name:Tags[?Key==`Name`].Value|[0],ID:NatGatewayId,State:State,Subnet:SubnetId,PublicIP:NatGatewayAddresses[0].PublicIp,AllocationId:NatGatewayAddresses[0].AllocationId}' \
  --output table
```

Elastic IP確認:

```bash
aws ec2 describe-addresses \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-eip-ngw-01,sample-eip-ngw-02 \
  --query 'Addresses[*].{Name:Tags[?Key==`Name`].Value|[0],AllocationId:AllocationId,PublicIp:PublicIp,AssociationId:AssociationId}' \
  --output table
```

NAT GatewayとElastic IPは課金対象のため、作業後に必ず削除確認します。

## 7. Route Tableの確認

VPC配下のRoute Table確認:

```bash
aws ec2 describe-route-tables \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'RouteTables[*].{Name:Tags[?Key==`Name`].Value|[0],ID:RouteTableId,AssociatedSubnets:Associations[?SubnetId!=`null`].SubnetId,IGW:Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId|[0],NGW:Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId|[0]}' \
  --output table
```

## 8. Security Groupの確認

Security Group一覧:

```bash
aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,Description:Description}' \
  --output table
```

踏み台サーバー用・ALB用・Web用Security Group確認:

```bash
aws ec2 describe-security-groups \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=group-name,Values=sample-sg-bastion,sample-sg-elb,sample-sg-web \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,Rules:IpPermissions[*].{Protocol:IpProtocol,FromPort:FromPort,ToPort:ToPort,Cidr:IpRanges[0].CidrIp,SourceGroup:UserIdGroupPairs[0].GroupId}}' \
  --output table
```

自分のグローバルIP確認:

```bash
curl -s https://checkip.amazonaws.com
```

SSHを許可する場合、実運用では `0.0.0.0/0` ではなく、自分のIP `/32` に絞ります。

## 9. EC2の確認

起動中インスタンス一覧:

```bash
aws ec2 describe-instances \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name,Type:InstanceType,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,Subnet:SubnetId}' \
  --output table
```

Bastion確認:

```bash
aws ec2 describe-instances \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-ec2-bastion \
  --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name,Type:InstanceType,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress}' \
  --output table
```

Webサーバー確認:

```bash
aws ec2 describe-instances \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-ec2-web01,sample-ec2-web02 \
  --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name,Type:InstanceType,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,Subnet:SubnetId}' \
  --output table
```

## 10. AMI / インスタンスタイプ確認

Amazon Linux 2023 最新AMIを取得:

```bash
aws ssm get-parameter \
  --profile learning \
  --region ap-northeast-1 \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' \
  --output text
```

無料枠対象のインスタンスタイプ確認:

```bash
aws ec2 describe-instance-types \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=free-tier-eligible,Values=true \
  --query 'InstanceTypes[*].InstanceType' \
  --output text
```

## 11. SSH接続確認

Bastionへ接続:

```bash
ssh -i nobu.pem ec2-user@<Bastion Public IP>
```

踏み台経由でPrivate SubnetのWebサーバーへ接続:

```bash
ssh -i nobu.pem -J ec2-user@<Bastion Public IP> ec2-user@<Web Private IP>
```

`~/.ssh/config` を使う場合:

```sshconfig
Host bastion
  HostName <Bastion Public IP>
  User ec2-user
  IdentityFile /path/to/nobu.pem
  IdentitiesOnly yes

Host web01
  HostName <Web01 Private IP>
  User ec2-user
  IdentityFile /path/to/nobu.pem
  IdentitiesOnly yes
  ProxyJump bastion

Host web02
  HostName <Web02 Private IP>
  User ec2-user
  IdentityFile /path/to/nobu.pem
  IdentitiesOnly yes
  ProxyJump bastion
```

接続:

```bash
ssh bastion
ssh web01
ssh web02
```

## 12. 料金確認

Cost Explorerで今月の概算料金を確認:

```bash
START_DATE="$(date +%Y-%m-01)"
END_DATE="$(date -v+1d +%Y-%m-%d)"

aws ce get-cost-and-usage \
  --profile learning \
  --region us-east-1 \
  --time-period Start="$START_DATE",End="$END_DATE" \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --query 'ResultsByTime[0].Total.UnblendedCost' \
  --output table
```

サービス別料金:

```bash
aws ce get-cost-and-usage \
  --profile learning \
  --region us-east-1 \
  --time-period Start="$START_DATE",End="$END_DATE" \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[0].Groups[*].[Keys[0], Metrics.UnblendedCost.Amount, Metrics.UnblendedCost.Unit]' \
  --output table
```

Cost Explorerは反映に時間がかかるため、即時の課金確認には向きません。

## 13. 削除確認

学習後、削除漏れがないか確認します。

VPC:

```bash
aws ec2 describe-vpcs \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=tag:Name,Values=sample-vpc
```

NAT Gateway:

```bash
aws ec2 describe-nat-gateways \
  --profile learning \
  --region ap-northeast-1 \
  --filter Name=tag:Name,Values=sample-ngw-01,sample-ngw-02 \
  --query 'NatGateways[*].{Name:Tags[?Key==`Name`].Value|[0],ID:NatGatewayId,State:State}' \
  --output table
```

Elastic IP:

```bash
aws ec2 describe-addresses \
  --profile learning \
  --region ap-northeast-1 \
  --query 'Addresses[*].{AllocationId:AllocationId,PublicIp:PublicIp,AssociationId:AssociationId,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table
```

EC2:

```bash
aws ec2 describe-instances \
  --profile learning \
  --region ap-northeast-1 \
  --filters Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[*].Instances[*].{Name:Tags[?Key==`Name`].Value|[0],ID:InstanceId,State:State.Name,Type:InstanceType}' \
  --output table
```

## 14. LocalStackを使う場合

LocalStackを操作する場合は、実AWSとは明確に分けます。

直接指定する例:

```bash
aws --endpoint-url http://localhost:4566 sts get-caller-identity
```

自宅Ubuntu上のLocalStackを指定する例:

```bash
aws --endpoint-url http://192.168.40.100:4566 sts get-caller-identity
```

aliasを使う場合:

```bash
alias awslocal='aws --endpoint-url=http://localhost:4566'
```

LocalStack確認:

```bash
curl http://localhost:4566/_localstack/health
```

LocalStack利用時は、実AWS用の `aws` コマンドと混同しないようにします。

推奨:

```bash
aws      # 実AWS用
awslocal # LocalStack用
```

