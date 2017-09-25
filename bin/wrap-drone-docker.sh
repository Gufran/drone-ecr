#!/bin/sh

# support PLUGIN_ and ECR_ variables
[ -n "$ECR_REGION" ] && export PLUGIN_REGION=${ECR_REGION}
[ -n "$ECR_ACCESS_KEY" ] && export PLUGIN_ACCESS_KEY=${ECR_ACCESS_KEY}
[ -n "$ECR_SECRET_KEY" ] && export PLUGIN_SECRET_KEY=${ECR_SECRET_KEY}
[ -n "$ECR_CREATE_REPOSITORY" ] && export PLUGIN_SECRET_KEY=${PLUGIN_CREATE_REPOSITORY}

ci_role=${PLUGIN_USE_CI_ROLE:-'ci'}
session_id="${DRONE_COMMIT_SHA:0:10}-${DRONE_BUILD_NUMBER}"

# set the region
export AWS_DEFAULT_REGION=${PLUGIN_REGION:-'us-east-1'}

if [ -n "$PLUGIN_ACCESS_KEY" ] && [ -n "$PLUGIN_SECRET_KEY" ]; then
  export AWS_ACCESS_KEY_ID=${PLUGIN_ACCESS_KEY}
  export AWS_SECRET_ACCESS_KEY=${PLUGIN_SECRET_KEY}
else
  account_id=$(env | grep "account_id_$account" | cut -d= -f2)
  iam_creds=$(aws sts assume-role --role-arn "arn:aws:iam::${account_id}:role/${ci_role}" --role-session-name "drone-${session_id}" --region=${AWS_DEFAULT_REGION} | python -m json.tool)

  export AWS_ACCESS_KEY_ID=$(echo $iam_creds | grep AccessKeyId | tr -d '" ,' | cut -d ':' -f2)
  export AWS_SECRET_ACCESS_KEY=$(echo $iam_creds | grep SecretAccessKey | tr -d '" ,' | cut -d ':' -f2)
  export AWS_SESSION_TOKEN=$(echo $iam_creds | grep SessionToken | tr -d '" ,' | cut -d ':' -f2)
fi

# get token from aws
aws_auth=$(aws ecr get-authorization-token --output text)

# map some ecr specific variable names to their docker equivalents
export DOCKER_USERNAME=AWS
export DOCKER_PASSWORD=$(echo $aws_auth | cut -d ' ' -f2 | base64 -d | cut -d: -f2)
export DOCKER_REGISTRY=$(echo $aws_auth | cut -d ' ' -f4)

# invoke the docker plugin
/bin/drone-docker "$@"
