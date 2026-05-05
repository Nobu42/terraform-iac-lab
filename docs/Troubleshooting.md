# Troubleshooting

このドキュメントは、AWS CLI、Shell Script、AnsibleでAWS学習環境を構築する中で発生したエラーと対応内容をまとめたものです。

単にエラーを記録するだけでなく、原因、対応、再発防止策を整理することで、今後のTerraform化や運用改善につなげることを目的とします。

## 1. AWS CLIがLocalStackへ接続してしまう

### 事象

実AWSへ接続したいが、AWS CLIがLocalStackのEndpointへ接続してしまった。

```text
aws: [ERROR]: Could not connect to the endpoint URL: "http://192.168.40.100:4566/"
```

### 原因

過去にLocalStack検証用として設定したaliasや環境変数が残っていた。

例:

```bash
AWS_ENDPOINT_URL
LOCALSTACK_HOST
alias aws='aws --endpoint-url=...'
```

### 対応

設定ファイルを確認した。

```bash
grep -n "alias aws" ~/.bashrc ~/.bash_profile ~/.profile ~/.zshrc 2>/dev/null
echo "$AWS_ENDPOINT_URL"
echo "$LOCALSTACK_HOST"
type -a aws
```

実AWS用の各スクリプトでは、冒頭でLocalStack向け設定を解除するようにした。

```bash
unalias aws 2>/dev/null || true
unset AWS_ENDPOINT_URL
unset LOCALSTACK_HOST
```

### 学んだこと

AWS CLIの接続先は、aliasや環境変数の影響を受ける。
実AWS向けスクリプトでは、LocalStack向け設定を明示的に解除してから実行する。

---

## 2. `<sample-tgのARN>` をそのまま実行してしまう

### 事象

Target Group ARNを指定する箇所で、プレースホルダーをそのまま実行した。

```bash
--target-group-arn <sample-tgのARN>
```

エラー:

```text
-bash: sample-tgのARN: No such file or directory
```

### 原因

`<...>` は説明用のプレースホルダーであり、bashではリダイレクトとして解釈される。

### 対応

AWS CLIでTarget Group ARNを取得して変数に格納した。

```bash
TG_ARN=$(aws elbv2 describe-target-groups \
  --profile learning \
  --region ap-northeast-1 \
  --names sample-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)
```

その後、変数を使って実行した。

```bash
aws elbv2 describe-target-health \
  --profile learning \
  --region ap-northeast-1 \
  --target-group-arn "$TG_ARN"
```

### 学んだこと

手順書上の `<...>` は実際の値に置き換える必要がある。
ARNなどの動的な値は、AWS CLIで取得して変数化すると安全である。

---

## 3. Amazon Linux 2023で `mysql` パッケージが見つからない

### 事象

WebサーバーからRDSへ接続確認するため、MySQLクライアントをインストールしようとした。

```bash
sudo yum -y install mysql
sudo dnf -y install mysql
```

エラー:

```text
No match for argument: mysql
Error: Unable to find a match: mysql
```

### 原因

Amazon Linux 2023では、書籍に記載されている `mysql` パッケージ名では提供されていなかった。

### 対応

MariaDB系パッケージを検索した。

```bash
sudo dnf search mariadb
```

`mariadb105` をインストールした。

```bash
sudo dnf -y install mariadb105
```

確認:

```bash
mysql --version
```

結果:

```text
mysql  Ver 15.1 Distrib 10.5.29-MariaDB
```

RDSへの接続確認:

```bash
mysqladmin ping -u adminuser -p -h sample-db.cz0uoiium9n7.ap-northeast-1.rds.amazonaws.com
```

結果:

```text
mysqld is alive
```

### 学んだこと

Amazon Linux 2023では、書籍のAmazon Linux 2向けパッケージ名がそのまま使えない場合がある。
パッケージが見つからない場合は、`dnf search` で現在のリポジトリに存在する名前を確認する。

---

## 4. RDS Endpointのドメイン名を誤った

### 事象

RDSへ接続しようとしたが、ホスト名が解決できなかった。

```text
Unknown MySQL server host 'sampledb.cginsnmcx6vh.ap.northeast-1.rds.amazonaws.com'
```

### 原因

RDS Endpointの文字列が誤っていた。
`ap.northeast-1` のようにドット位置が間違っていた。

### 対応

AWS CLIまたはRDS作成時の出力から正しいEndpointを確認した。

正しい例:

```text
sample-db.cz0uoiium9n7.ap-northeast-1.rds.amazonaws.com
```

接続確認:

```bash
mysqladmin ping -u adminuser -p -h sample-db.cz0uoiium9n7.ap-northeast-1.rds.amazonaws.com
```

結果:

```text
mysqld is alive
```

### 学んだこと

RDS Endpointは手入力せず、AWS CLIの出力からコピーする。
Private DNS `db.home` を作ることで、今後はEndpoint変更の影響を受けにくくできる。

---

## 5. S3バケット名が既に使われていた

### 事象

S3バケットを作成しようとしたが、既に使用済みだった。

```text
BucketAlreadyExists
The requested bucket name is not available.
The bucket namespace is shared by all users of the system.
```

### 原因

S3バケット名はAWS全体でグローバルに一意である必要がある。
他のAWSアカウントで同じ名前が使われていた。

### 対応

より一意性の高いバケット名に変更した。

```text
nobu-terraform-iac-lab-upload
```

### 学んだこと

S3バケット名はアカウント内ではなく、AWS全体で一意である。
学習用でも、ユーザー名やプロジェクト名を含めた一意な名前にする。

---

## 6. AWS CLIのJMESPathで `split()` が使えない

### 事象

IAM Instance Profile Associationの確認で、`split()` を使ったqueryが失敗した。

```text
aws: [ERROR]: Unknown function: split()
```

### 原因

AWS CLIのJMESPathでは、環境やバージョンによって利用できない関数がある。
`split()` は利用できなかった。

### 対応

`split()` を使わず、ARN全体またはNameを直接出すqueryへ変更した。

### 学んだこと

AWS CLIの `--query` は便利だが、使える関数に制限がある。
複雑な加工をCLI queryだけで行わず、必要なら表示内容をシンプルにする。

---

## 7. Public DNSとPrivate DNSの確認場所を誤った

### 事象

Private Hosted Zone `home` に作成した `web01.home` や `db.home` をMacから引いたところ、NXDOMAINになった。

```bash
dig web01.home
dig db.home
```

結果:

```text
status: NXDOMAIN
```

### 原因

Route 53 Private Hosted Zoneは、関連付けたVPC内からのみ名前解決できる。
Macの自宅DNSからは解決できない。

### 対応

VPC内のEC2から確認した。

```bash
dig web01.home
dig db.home
```

結果:

```text
web01.home. 300 IN A 10.0.66.158
db.home. 300 IN CNAME sample-db.cz0uoiium9n7.ap-northeast-1.rds.amazonaws.com.
```

`db.home` を使ったRDS接続確認も成功した。

```bash
mysqladmin ping -u adminuser -p -h db.home
```

結果:

```text
mysqld is alive
```

### 学んだこと

Public DNSはインターネット側から確認できる。
Private DNSはVPC内のEC2から確認する必要がある。

---

## 8. DNS名前解決をtcpdumpで確認した

### 事象

Public DNSの名前解決が実際に行われていることを確認したかった。

### 対応

MacでDNS通信をキャプチャした。

```bash
sudo tcpdump -i en0 -n port 53
```

確認例:

```text
192.168.40.101.63679 > 192.168.40.208.53: A? www.nobu-iac-lab.com.
192.168.40.208.53 > 192.168.40.101.63679: A 3.115.185.66, A 13.192.190.8
```

### 学んだこと

`dig` の結果だけでなく、`tcpdump` を使うことでDNS問い合わせと応答のパケットを確認できる。
`192.168.40.208` は自宅のDNSサーバーである。

---

## 9. ALB Target Healthがunhealthyになった

### 事象

ALBのTarget Groupで一部のWebサーバーがunhealthyになった。

```text
Target.FailedHealthChecks
Health checks failed
```

### 原因

Webサーバー側で、ALBのヘルスチェック対象ポート `3000` のアプリケーションが起動していなかった。
または、`python3 -m http.server 3000` を起動したディレクトリの `index.html` が想定と異なっていた。

### 対応

Webサーバー上で3000番ポートのHTTPサーバーを起動した。

```bash
python3 -m http.server 3000
```

Target Healthを確認した。

```bash
aws elbv2 describe-target-health \
  --profile learning \
  --region ap-northeast-1 \
  --target-group-arn "$TG_ARN" \
  --output table
```

### 学んだこと

ALBのSecurity Group設定だけでなく、Target側でアプリケーションが起動している必要がある。
ヘルスチェックパス `/` に正常応答できないとTargetはhealthyにならない。

---

## 10. Amazon Linux 2023に `amazon-linux-extras` がない

### 事象

書籍の手順ではnginxやRedis導入に `amazon-linux-extras` を使っていた。

```bash
sudo amazon-linux-extras install -y nginx
```

しかしAmazon Linux 2023では利用できなかった。

### 原因

`amazon-linux-extras` はAmazon Linux 2で使われていた仕組みであり、Amazon Linux 2023では基本的に使用しない。

### 対応

Amazon Linux 2023では `dnf` を使う。

nginx:

```bash
sudo dnf -y install nginx
```

Redis:

```bash
sudo dnf -y install redis6
```

### 学んだこと

書籍がAmazon Linux 2前提の場合、Amazon Linux 2023ではパッケージ導入手順を読み替える必要がある。

---

## 11. Redisクライアント名が `redis-cli` ではなく `redis6-cli` だった

### 事象

ElastiCache接続確認のためRedisクライアントをインストールしたが、`redis-cli` が見つからなかった。

```bash
redis-cli --version
```

結果:

```text
-bash: redis-cli: command not found
```

### 原因

Amazon Linux 2023の `redis6` パッケージでは、コマンド名が `redis6-cli` だった。

### 対応

パッケージに含まれるコマンドを確認した。

```bash
rpm -ql redis6 | grep bin
```

結果:

```text
/usr/bin/redis6-cli
/usr/bin/redis6-server
```

確認:

```bash
redis6-cli --version
```

ElastiCache接続確認:

```bash
redis6-cli -c \
  -h sample-elasticache.0wkp6l.clustercfg.apne1.cache.amazonaws.com \
  -p 6379 \
  ping
```

結果:

```text
PONG
```

読み書き確認:

```bash
redis6-cli -c \
  -h sample-elasticache.0wkp6l.clustercfg.apne1.cache.amazonaws.com \
  -p 6379 \
  set test-key "hello redis"

redis6-cli -c \
  -h sample-elasticache.0wkp6l.clustercfg.apne1.cache.amazonaws.com \
  -p 6379 \
  get test-key
```

結果:

```text
OK
"hello redis"
```

### 学んだこと

Redis Cluster構成では `redis6-cli` に `-c` を付ける。
`-c` を付けることで、キーが別シャードにある場合のリダイレクトに対応できる。

---

## 12. ElastiCacheを削除し忘れてSubnet / Security Group削除に失敗した

### 事象

`cleanup_all.sh` 実行時、Security GroupやSubnet削除でエラーになった。

```text
DependencyViolation
resource sg-xxxxxxxx has a dependent object
The subnet 'subnet-xxxxxxxx' has dependencies and cannot be deleted.
```

### 原因

ElastiCache Replication GroupがPrivate SubnetとSecurity Groupを使用していた。
ElastiCacheを先に削除しないと、SubnetやSecurity Groupを削除できなかった。

### 対応

ElastiCache削除処理を `cleanup_all.sh` に追加した。

```bash
aws elasticache delete-replication-group \
  --profile learning \
  --region ap-northeast-1 \
  --replication-group-id sample-elasticache \
  --no-retain-primary-cluster

aws elasticache wait replication-group-deleted \
  --profile learning \
  --region ap-northeast-1 \
  --replication-group-id sample-elasticache

aws elasticache delete-cache-subnet-group \
  --profile learning \
  --region ap-northeast-1 \
  --cache-subnet-group-name sample-elasticache-sg
```

Security Group削除対象にも `sample-sg-elasticache` を追加した。

### 学んだこと

AWSリソース削除時は依存関係の順序が重要である。
ElastiCacheはSubnet GroupとSecurity Groupを使用するため、Subnet / Security Groupより先に削除する。

---

## 13. `sample-vpc` が残った状態で `All_Setup.sh` を実行してCIDR衝突した

### 事象

`All_Setup.sh` 実行時、VPC作成後にSubnet作成で失敗した。

```text
InvalidSubnet.Conflict
The CIDR '10.0.0.0/20' conflicts with another subnet
```

### 原因

前回の `sample-vpc` が残っている状態で、新しい `sample-vpc` を作成してしまった。
その結果、`sample-vpc` が複数存在し、後続スクリプトが古いVPCを参照してSubnet CIDRが衝突した。

### 対応

`cleanup_all.sh` を実行して既存VPCを削除した。
さらに、`All_Setup.sh` の冒頭に既存VPCチェックを追加した。

```bash
EXISTING_VPCS=$(aws ec2 describe-vpcs \
  --profile "$PROFILE" \
  --region "$REGION" \
  --filters Name=tag:Name,Values="$VPC_NAME" \
  --query 'Vpcs[*].VpcId' \
  --output text)

if [ -n "$EXISTING_VPCS" ]; then
  echo "Error: Existing VPC found."
  echo "VPC IDs : $EXISTING_VPCS"
  exit 1
fi
```

### 学んだこと

日次で削除・再構築する運用では、構築前の残存確認が重要である。
`All_Setup.sh` はクリーンな状態からのみ実行するようにガードを入れる。

---

## 14. SES Production Accessが承認されなかった

### 事象

SESのSandbox外利用を申請したが、承認されなかった。

```text
現時点では制限の引き上げを承認することができません。
```

### 原因

AWS Trust and Safetyの審査基準により、Production Accessが承認されなかった。
詳細な審査基準は公開されていない。

### 対応

Sandbox環境で検証を継続する方針にした。

Sandbox環境でも以下は確認済み:

- Domain Identity
- DKIM
- SPF
- DMARC
- SMTP送信
- SES受信
- S3への受信メール保存

ポートフォリオ上は以下のように整理する。

```text
Amazon SESはSandbox環境で検証。
Domain Identity、DKIM、SPF、DMARC、SMTP認証、S3へのメール受信保存を確認済み。
Production AccessはAWS審査の都合により未承認のため、送信先は検証済みメールアドレスに限定。
```

### 学んだこと

SESはメール品質や不正利用対策が厳しいサービスであり、個人学習用途ではProduction Accessが承認されない場合がある。
Sandbox環境でも、送信・受信・DNS認証の基本構成は十分に検証できる。

---

## 15. CloudWatch CLIの `--statistics` 指定を誤った

### 事象

EC2 CPU使用率を確認するためCloudWatch CLIを実行したが、`--statistics` 指定でエラーになった。

```text
The parameter Statistics.member.1.<list element> must be a value in the set
[SampleCount, Average, Sum, Minimum, Maximum].
```

### 原因

`--statistics` に `Average,Maximum` のようなカンマ区切りを指定していた。

### 対応

スペース区切りで指定した。

```bash
aws cloudwatch get-metric-statistics \
  --profile learning \
  --region ap-northeast-1 \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<InstanceId> \
  --start-time "$(date -u -v-30M +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 300 \
  --statistics Average Maximum \
  --query 'Datapoints[*].{Time:Timestamp,Average:Average,Maximum:Maximum}' \
  --output table
```

### 学んだこと

AWS CLIの複数値オプションは、カンマ区切りではなくスペース区切りで指定するものがある。

---

## 16. t3.microでRubyビルドが重く、SSHが不安定になった

### 事象

AnsibleでRuby 3.3.6をrbenv経由でインストール中、web01へのSSHが不安定になった。

```text
Connection timed out during banner exchange
Connection to UNKNOWN port 65535 timed out
```

Ansibleでも到達不能になった。

```text
UNREACHABLE
Failed to connect to the host via ssh
```

### 原因

`t3.micro` 上でRubyをソースビルドしたため、CPUやメモリに余裕がなくなった。
CloudWatchでCPU使用率を確認すると、Rubyビルド中に高いCPU使用率が出ていた。

```text
Maximum 99.88
Average 53%
```

### 対応

Ansible側で以下の対策を行った。

`ansible.cfg` を作成:

```ini
[defaults]
inventory = inventory/hosts.ini
host_key_checking = False
timeout = 60

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=600s -o ServerAliveInterval=30 -o ServerAliveCountMax=10
pipelining = True
```

`05_ruby.yml` に `serial: 1` を追加し、web01 / web02を同時にビルドしないようにした。

```yaml
- name: Install Ruby with rbenv
  hosts: web
  become: true
  serial: 1
```

また、今後のRailsデプロイ作業を考慮し、Webサーバーのインスタンスタイプを `t3.micro` から `t3.small` に変更する方針にした。

### 学んだこと

小さいEC2インスタンスでソースビルドを行うと、SSHやAnsibleの接続が不安定になる場合がある。
構成管理では、処理内容に応じたインスタンスサイズや実行順序を考慮する必要がある。

---

## 17. AnsibleはMacから実行する

### 事象

Webサーバー上で `ansible` コマンドを実行し、コマンドが見つからなかった。

```text
-bash: ansible: command not found
```

### 原因

Ansibleは管理対象サーバーではなく、操作元のMacにインストールして実行する構成だった。
web01 / web02にAnsible本体を入れる必要はない。

### 対応

MacにAnsibleをインストールした。

```bash
brew install ansible
```

MacからBastion経由でweb01 / web02へ接続した。

```bash
ansible -i inventory/hosts.ini web -m ping
```

結果:

```text
web01 | SUCCESS => { "ping": "pong" }
web02 | SUCCESS => { "ping": "pong" }
```

### 学んだこと

AnsibleはPush型の構成管理ツールであり、操作元からSSHで対象サーバーへ接続して処理を実行する。
管理対象サーバーにはAnsible本体ではなく、Pythonがあればよい。

---

## 18. AnsibleのPython interpreter warning

### 事象

Ansible ping実行時にPython interpreterのwarningが表示された。

```text
Host 'web01' is using the discovered Python interpreter at '/usr/bin/python3.9'
```

### 原因

Ansibleが接続先のPythonを自動検出していた。
将来別のPythonがインストールされた場合、検出されるPythonが変わる可能性があるためwarningが出た。

### 対応

`inventory/hosts.ini` にPython interpreterを明示した。

```ini
[web:vars]
ansible_python_interpreter=/usr/bin/python3.9
```

### 学んだこと

Ansibleは接続先でPythonモジュールを実行する。
Amazon Linux 2023では `/usr/bin/python3.9` を明示することで、warningを抑制できる。

---

## 19. 書籍のRuby / Railsバージョンが古かった

### 事象

書籍では以下のバージョンが指定されていた。

```bash
rbenv install 2.6.6
rbenv global 2.6.6
gem install rails -v 5.1.6
```

### 原因

書籍が2023年以前の環境を前提としており、Ruby 2.6 / Rails 5.1は現在では古い。
Ruby 2.6系はEOLであり、Amazon Linux 2023のOpenSSL 3系との相性でも問題が出る可能性がある。

### 対応

書籍の手順は参考にしつつ、実際のポートフォリオでは新しいバージョンを採用する方針にした。

採用方針:

```text
Ruby 3系
Rails 7系以降
```

Ansibleではrbenvを使い、Rubyバージョンを変数として管理する。

```yaml
vars:
  ruby_version: "3.3.6"
```

### 学んだこと

書籍の手順をそのまま写すのではなく、現在のOS、ミドルウェア、セキュリティサポート状況に合わせて読み替える必要がある。
古い手順を現代環境に移植すること自体が重要な学習になる。

## 20. Public DNSレコード再作成後にMacで名前解決できなかった

### 事象

`cleanup_all.sh` で日次リソースを削除した後、翌日に `All_Setup.sh` を実行して `www.nobu-iac-lab.com` のRoute 53 Aliasレコードを再作成した。

Route 53上では `www.nobu-iac-lab.com` のA Aliasレコードが存在していたが、Macから `curl` を実行すると名前解決に失敗した。

```bash
curl -I https://www.nobu-iac-lab.com
```

エラー:

```text
curl: (6) Could not resolve host: www.nobu-iac-lab.com
```

Route 53には以下のようにレコードが存在していた。

```text
www.nobu-iac-lab.com. A Alias -> sample-elb-xxxxxxxx.ap-northeast-1.elb.amazonaws.com.
```

### 原因

前日に `cleanup_all.sh` で `www.nobu-iac-lab.com` の一時DNSレコードを削除した際、Mac側が「名前が存在しない」というDNS結果をキャッシュしていた可能性が高い。

翌日にRoute 53へ同名レコードを再作成しても、MacのDNSキャッシュが古い結果を返していたため、`curl` では名前解決できなかった。

自宅DNSにはRaspberry PiのCoreDNSを利用しているが、今回はRoute 53上のレコードが存在しており、MacのDNSキャッシュ削除で解消したため、Mac側キャッシュの影響と判断した。

### 対応

まずRoute 53上にPublic DNSレコードが存在することを確認した。

```bash
aws route53 list-resource-record-sets \
  --profile learning \
  --hosted-zone-id Z02886402CZFSQE5OSSQ \
  --query "ResourceRecordSets[?Name==\`www.nobu-iac-lab.com.\`]" \
  --output table
```

外部DNSで名前解決できるか確認する場合は、Google Public DNSやCloudflare DNSを明示して確認する。

```bash
dig www.nobu-iac-lab.com @8.8.8.8
dig www.nobu-iac-lab.com @1.1.1.1
dig www.nobu-iac-lab.com
```

MacのDNSキャッシュを削除した。

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

その後、再度 `curl` を実行し、名前解決できることを確認した。

### 学んだこと

Route 53上にレコードが存在していても、ローカル端末やローカルDNSのキャッシュにより、一時的に古い名前解決結果が返ることがある。

DNSトラブル時は以下の順で切り分けるとよい。

1. Route 53に対象レコードが存在するか確認する
2. `dig @8.8.8.8` や `dig @1.1.1.1` で外部DNSから確認する
3. 通常の `dig` でローカル環境の名前解決結果を確認する
4. 外部DNSでは引けるがローカルだけ失敗する場合、Macや自宅DNSのキャッシュを疑う

---

## 21. Ruby導入済みWebベースAMIを作成した

### 事象

日次で `cleanup_all.sh` によりAWSリソースを削除し、翌日に `All_Setup.sh` で再構築する運用では、Ansibleの `05_ruby.yml` によるRubyソースビルドに時間がかかった。

特にWeb EC2を毎回作り直す構成では、Ruby、Bundler、nginx、deployユーザーなど、毎回同じミドルウェア導入を繰り返すことになる。

### 対応

`web01` に対して以下のPlaybookを実行し、Ruby 3.3.6 / Bundler 4.0.11 まで導入した状態でAMIを作成した。

```bash
ansible-playbook playbooks/01_ping.yml
ansible-playbook playbooks/02_packages.yml
ansible-playbook playbooks/03_deploy_user.yml
ansible-playbook playbooks/04_nginx.yml
ansible-playbook playbooks/05_ruby.yml
```

作成コマンド:

```bash
../01-aws-cli/scripts/20_create_web_base_ami.sh
```

作成結果:

```text
AMI ID: ami-00f86224c38cc3b8c
Name  : web-base-ruby336-rails72-20260505-102118
State : available
```

このAMIは、次回以降 `08_Web_server_setup.sh` でWeb EC2を作成する際のベースAMIとして利用する。

### 注意点

AMIそのものというより、AMIに紐づくEBSスナップショットに保存料金が発生する。

そのため、学習用途では以下の方針とする。

- Ruby導入済みWebベースAMIは原則1世代のみ保持する
- 古いAMIを使わなくなったら、AMI登録解除とEBSスナップショット削除を行う
- Fast Snapshot Restoreは有効化しない
- アプリケーション本体、DBパスワード、SES SMTPパスワード、secret_key_baseはAMIに含めない
- RailsアプリケーションはAnsibleで後から配置する

### 学んだこと

毎回すべてを構築するだけでなく、時間のかかるミドルウェア導入部分をAMI化することで、再構築時間を短縮できる。

一方で、AMIはバックアップ兼テンプレートとして便利だが、EBSスナップショットの削除漏れが課金につながるため、作成だけでなく削除運用も合わせて設計する必要がある。

---

## 22. ALB配下のRailsでHTTPSリダイレクトループが発生した

### 事象

Rails 7.2アプリをPuma + nginxで起動し、ALB + ACM + Route 53経由で `https://www.nobu-iac-lab.com` にアクセスしたところ、ブラウザで以下のエラーになった。

```text
Load cannot follow more than 20 redirections
```

`curl -I` でもHTTPSアクセス時にリダイレクトが繰り返されている状態だった。

### 原因

ALBでHTTPSを終端し、ALBからWeb EC2上のnginxへはHTTPで転送している。

当初のnginx設定では、Railsへ以下のようにヘッダーを渡していた。

```nginx
proxy_set_header X-Forwarded-Proto $scheme;
```

nginxから見るとALBからの通信はHTTPであるため、`$scheme` は `http` になる。

その結果、Rails production側は「現在のリクエストはHTTPで来ている」と判断し、HTTPSへリダイレクトする。

しかしブラウザは既にHTTPSでALBへアクセスしており、ALBからnginxへは再びHTTPで転送されるため、以下のループになった。

```text
Browser -> HTTPS -> ALB -> HTTP -> nginx -> Rails
Rails -> HTTPSへリダイレクト
Browser -> HTTPS -> ALB -> HTTP -> nginx -> Rails
```

### 対応

nginxでALBが付与した `X-Forwarded-Proto` を優先してRailsへ渡すようにした。

```nginx
map $http_x_forwarded_proto $rails_x_forwarded_proto {
    default $http_x_forwarded_proto;
    "" $scheme;
}

proxy_set_header X-Forwarded-Proto $rails_x_forwarded_proto;
```

また、Rails production側でもALB配下でHTTPSとして扱うため、以下を設定した。

```ruby
config.assume_ssl = true
config.force_ssl = true
```

修正後、以下で `HTTP/2 200` を確認した。

```bash
curl -I https://www.nobu-iac-lab.com
```

確認結果:

```text
HTTP/2 200
server: nginx/1.28.3
strict-transport-security: max-age=63072000; includeSubDomains
```

### 学んだこと

ALBでHTTPS終端する場合、アプリケーションサーバーから見る通信はHTTPになる。

Rails productionではSSL関連の判断に `X-Forwarded-Proto` が重要になるため、nginxでALBから受け取ったヘッダーを正しく引き継ぐ必要がある。

---

## 23. Web EC2 2台構成でログイン時にCSRFエラーが発生した

### 事象

Rails 7.2アプリでログインフォームを送信すると、ブラウザに以下の画面が表示された。

```text
The change you wanted was rejected.

Maybe you tried to change something you didn't have access to.
```

Pumaログを確認すると、以下のエラーが出ていた。

```text
Can't verify CSRF token authenticity.
ActionController::InvalidAuthenticityToken
```

### 確認コマンド

Railsログは `production.log` ではなくPumaのstdoutに出力されていた。

```bash
ssh web01
sudo ls -l /var/www/nobu-iac-lab/log
sudo tail -n 120 /var/www/nobu-iac-lab/log/puma.stdout.log
```

リアルタイムで確認する場合:

```bash
sudo journalctl -u puma-nobu-iac-lab -f
```

### 原因

`web01` と `web02` で `SECRET_KEY_BASE` が別々に生成されていた。

Rails productionでは、Cookie署名やCSRF tokenの検証に `SECRET_KEY_BASE` を利用する。

ALB配下では、以下のようにGETとPOSTが別々のWeb EC2へ振り分けられることがある。

```text
GET  /login   -> web01
POST /session -> web02
```

このとき、`web01` が発行したCSRF tokenを `web02` が検証するには、両方のWeb EC2で同じ `SECRET_KEY_BASE` を使う必要がある。

しかし当初は各EC2で個別に `SECRET_KEY_BASE` を生成していたため、別インスタンスへ振り分けられたPOSTリクエストで検証に失敗した。

### 対応

Ansible実行元のMacで共通の `SECRET_KEY_BASE` を生成し、`web01` / `web02` の両方へ同じ値を配布するようにした。

```bash
export SECRET_KEY_BASE=$(openssl rand -hex 64)
export DB_MASTER_PASSWORD='RDS作成時のパスワード'
ansible-playbook playbooks/08_sample_app_rails72.yml
```

Playbookでは `/etc/nobu-iac-lab.env` に以下を設定する。

```text
SECRET_KEY_BASE=<Mac側で生成した共通値>
```

`/etc/nobu-iac-lab.env` は以下の権限にした。

```text
owner: root
group: deploy
mode : 0640
```

Pumaはdeployユーザーで動作するため、deployグループに読み取り権限を付けた。

修正後、ブラウザで以下のユーザーでログインできることを確認した。

```text
nobu@example.com
password
```

### 学んだこと

Webサーバーを複数台にする場合、Railsの `SECRET_KEY_BASE` は全台で共有する必要がある。

単体EC2では発生しない問題でも、ALB配下の複数台構成にすると、CookieやCSRF tokenなどステートをまたぐ処理で問題が出る。

---

## 24. Active StorageのmigrationがWeb EC2ごとに生成されてRDSで衝突した

### 事象

Rails 7.2アプリにActive Storageを追加し、`web01` / `web02` にAnsibleを実行したところ、`web02` のDB migrationで以下のエラーが発生した。

```text
Mysql2::Error: Table 'active_storage_blobs' already exists
```

### 原因

当初はPlaybook内で以下を実行していた。

```bash
bin/rails active_storage:install
```

このコマンドは、実行時刻を含むmigrationファイルを生成する。

そのため、`web01` と `web02` で別々のmigrationファイルが作成され、同じRDSに対して別バージョンのActive Storage migrationが実行された。

`web01` で既に `active_storage_blobs` が作成された後、`web02` が別migrationとして同じテーブルを作成しようとしたため失敗した。

### 対応

`bin/rails active_storage:install` を各EC2で実行する方式をやめ、Ansible管理の固定migrationを配置するようにした。

```text
db/migrate/20260505000050_create_active_storage_tables.rb
```

また、既にテーブルが存在している場合でも再実行で止まらないように、migration内で `table_exists?` を使って存在確認してから作成するようにした。

```ruby
unless table_exists?(:active_storage_blobs)
  create_table :active_storage_blobs do |t|
    # ...
  end
end
```

### 学んだこと

複数EC2から同じRDSへmigrationを適用する場合、各サーバーで自動生成されるmigrationファイルに差分が出ると衝突する。

インフラ自動化では、アプリケーション生成物も可能な限り固定化し、再実行しても同じ状態へ収束するようにする必要がある。

---

## 25. 画像投稿時に `413 Request Entity Too Large` が発生した

### 事象

Macのデスクトップから画像を選択してRailsアプリへ投稿したところ、以下のエラーが表示された。

```text
413 Request Entity Too Large
```

### 原因

画像投稿は `multipart/form-data` としてnginxへ送信される。

nginxのデフォルトではリクエストボディサイズの上限が小さく、Railsへ届く前にnginxが拒否していた。

### 対応

nginxのRails用serverブロックに以下を追加した。

```nginx
client_max_body_size 10m;
```

Rails側ではPostモデルで画像サイズを5MBまでに制限している。

```ruby
unless image.byte_size <= 5.megabytes
  errors.add(:image, "は5MB以下にしてください")
end
```

そのため、nginx側は少し余裕を持たせて10MBまで許可した。

修正後、画像付き投稿に成功した。

### S3保存確認

Active Storageの保存先をS3に設定しているため、画像アップロード後にS3オブジェクトが作成されることを確認した。

```bash
aws s3 ls s3://nobu-terraform-iac-lab-upload --recursive --profile learning
```

確認結果:

```text
2026-05-05 11:56:31    2112919 iruydzjgoenr4hh6pdfusunks08s
```

これにより、投稿画像がEC2ローカルではなくS3へ保存されていることを確認できた。

### 学んだこと

画像アップロードでは、Rails側のバリデーションだけでなく、nginxやALBなど途中経路のサイズ制限も確認する必要がある。

EC2をステートレスに近づけるため、投稿画像のような永続データはS3へ保存する構成が望ましい。

---

## 26. まとめ

今回の構築では、AWSリソースそのものだけでなく、以下の運用上の観点も確認できた。

- 構築前の残存リソース確認
- 削除順序と依存関係
- Amazon Linux 2023への読み替え
- DNSのPublic / Privateの違い
- DNSキャッシュによる名前解決トラブルの切り分け
- SES Sandbox制約
- ElastiCacheやRDSなどマネージドサービスの依存関係
- Ansible実行時のSSH安定性
- インスタンスタイプ選定
- Ruby導入済みAMIによる再構築時間短縮
- ALB配下RailsのHTTPSヘッダー処理
- 複数Web EC2構成での `SECRET_KEY_BASE` 共有
- Active Storage migrationの固定化
- nginxのアップロードサイズ制限
- Rails Active StorageからS3への画像保存
- コスト確認

今後は、これらの学びをTerraform化、Railsデプロイ、CloudWatch監視、CI/CD構成へ反映していく。
