#!/usr/bin/env bash
set -euo pipefail

##
## usage:
##   ./run-migrate.sh <ENV> [AWS_REGION] [GIT_SHA]
##
## <ENV>               : dev/stg/prod などの環境名 (ECS クラスター名／タスク定義のファミリ名にも使う)
## [AWS_REGION]        : デフォルト ap-northeast-1
## [GIT_SHA]           : イメージタグに使うコミット SHA（省略時は git rev-parse で取得）
##
if [ $# -lt 1 ]; then
  echo "Usage: $0 <ENV> [AWS_REGION] [GIT_SHA]"
  exit 1
fi

ENV="$1"
AWS_REGION="${2:-ap-northeast-1}"
GIT_SHA="${3:-$(git rev-parse --short HEAD)}"

# AWS CLI のプロファイルや認証は事前に行ってください

echo "=== Installing Session Manager Plugin (if necessary) ==="
if ! command -v session-manager-plugin &>/dev/null; then
  TMP_DEB="$(mktemp).deb"
  curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "$TMP_DEB"
  sudo dpkg -i "$TMP_DEB"
  rm -f "$TMP_DEB"
fi

echo "=== Preparing overrides.json ==="
cat > /tmp/overrides.json <<EOF
{
  "containerOverrides": [
    {
      "name": "php",
      "command": [ "sleep", "1h" ]
    }
  ]
}
EOF

echo "=== Fetching AWS_ACCOUNT_ID ==="
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

PHP_IMAGE_REPO_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ENV}-php:${GIT_SHA}"
FILTER=".containerDefinitions[0].image=\"$PHP_IMAGE_REPO_URI\""

echo "=== Describing existing task-definition [$ENV-migrate] and injecting new image ==="
aws ecs describe-task-definition \
  --task-definition "${ENV}-migrate" \
  --query="taskDefinition.{containerDefinitions: containerDefinitions[]}" \
  | jq "${FILTER}" \
  > /tmp/containers_definition.json

aws ecs describe-task-definition \
  --task-definition "${ENV}-migrate" \
  --query="taskDefinition" \
  | jq 'del(.taskDefinitionArn, .containerDefinitions, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)' \
  > /tmp/task_definition.json

NEW_TASK_DEF=$(jq -s 'add' /tmp/containers_definition.json /tmp/task_definition.json)
echo "$NEW_TASK_DEF" > /tmp/new-task-def.json

echo "=== Registering new task definition ==="
aws ecs register-task-definition \
  --cli-input-json file:///tmp/new-task-def.json

echo "=== Gathering subnets and security groups ==="
SUBNETS=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=${ENV}-public*" \
  --query="Subnets[].SubnetId | join(',', @)" \
  --output text \
)
SECURITY_GROUPS=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=${ENV}-app" \
  --query="SecurityGroups[].GroupId | join(',', @)" \
  --output text \
)


echo "=== Running ECS task ==="
aws ecs run-task \
  --cluster "$ENV" \
  --count 1 \
  --launch-type FARGATE \
  --enable-execute-command \
  --task-definition "${ENV}-migrate" \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUPS],assignPublicIp=ENABLED}" \
  --overrides file:///tmp/overrides.json \
  --output json

if ! TASK_ARN=$(aws ecs run-task \
  --cluster "$ENV" \
  --count 1 \
  --launch-type FARGATE \
  --enable-execute-command \
  --task-definition "${ENV}-migrate" \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUPS],assignPublicIp=ENABLED}" \
  --overrides file:///tmp/overrides.json \
  --output json \
  | jq -r '.tasks[0].taskArn'
); then
  echo "ERROR: ecs run-task failed" >&2
  exit 1
fi
echo "→ Started task: $TASK_ARN"

echo -n "Waiting for task to enter RUNNING"
until [ "$(aws ecs describe-tasks --cluster "$ENV" --tasks "$TASK_ARN" \
        | jq -r '.tasks[0].lastStatus')" = "RUNNING" ]; do
  echo -n "."
  sleep 5
done
echo " OK"

echo "Sleeping 30s to let container initialize..."
sleep 30

echo "=== Executing migrate command inside container ==="
RESULT=$(aws ecs execute-command \
  --cluster "$ENV" \
  --task "$TASK_ARN" \
  --container php \
  --interactive \
  --command "php artisan migrate --force" \
  --output text || true)

echo "--- migrate result ---"
echo "$RESULT"
echo "----------------------"

echo "=== Stopping task ==="
aws ecs stop-task --cluster "$ENV" --task "$TASK_ARN" >/dev/null

echo "=== Checking migrate exit status ==="
if echo "$RESULT" | grep -iq "error"; then
  echo "マイグレーションは失敗しました。"
  exit 1
else
  echo "マイグレーションは成功しました。"
  exit 0
fi