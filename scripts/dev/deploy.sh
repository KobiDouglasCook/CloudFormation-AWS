#!/bin/bash
set -e

BUCKET_NAME="fuego-socks-dev-templates"
STACK_NAME="fuego-socks-dev"
PARAM_FILE="parameters/dev.json"

echo ">>> Creating S3 bucket..."
aws s3 mb s3://$BUCKET_NAME || echo "Bucket already exists, continuing..."

echo ">>> Packaging CloudFormation templates..."
aws cloudformation package \
  --template-file root-stack.yaml \
  --s3-bucket $BUCKET_NAME \
  --output-template-file root-stack-packaged.yaml

echo ">>> Deploying CloudFormation stack..."
aws cloudformation deploy \
  --template-file root-stack-packaged.yaml \
  --stack-name $STACK_NAME \
  --parameter-overrides file://$PARAM_FILE \
  --capabilities CAPABILITY_NAMED_IAM

