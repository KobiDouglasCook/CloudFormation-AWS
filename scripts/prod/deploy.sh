#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

BUCKET_NAME="fuego-socks-prod-templates"
STACK_NAME="fuego-socks-prod"
PARAM_FILE="parameters/prod.json"

echo ">>> Creating S3 bucket..."
aws s3 mb s3://$BUCKET_NAME || echo "Bucket already exists, continuing..."

echo ">>> Packaging CloudFormation templates..."
aws cloudformation package \
  --template-file templates/root-stack.yaml \
  --s3-bucket $BUCKET_NAME \
  --output-template-file root-stack-packaged.yaml

echo ">>> Deploying CloudFormation stack..."
aws cloudformation deploy \
  --template-file root-stack-packaged.yaml \
  --stack-name $STACK_NAME \
  --parameter-overrides file://$PARAM_FILE \
  --capabilities CAPABILITY_NAMED_IAM

echo ">>> Successfully Created CloudFormation stack!"