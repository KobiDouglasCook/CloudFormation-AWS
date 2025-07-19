#!/bin/bash
set -e

STACK_NAME="prod-networking"
TEMPLATE_FILE="../../networking.yaml"
PARAMETERS_FILE="networking-params.json"

echo "Checking if CloudFormation stack '$STACK_NAME' exists..."

STACK_EXISTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].StackName" --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$STACK_EXISTS" == "$STACK_NAME" ]; then
  echo "Stack exists. Updating stack..."
  aws cloudformation update-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://"$TEMPLATE_FILE" \
    --parameters file://"$PARAMETERS_FILE" \
    --capabilities CAPABILITY_NAMED_IAM

  echo "Waiting for stack update to complete..."
  aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME"
  echo "Stack update completed successfully."
else
  echo "Stack does not exist. Creating stack..."
  aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://"$TEMPLATE_FILE" \
    --parameters file://"$PARAMETERS_FILE" \
    --capabilities CAPABILITY_NAMED_IAM

  echo "Waiting for stack creation to complete..."
  aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME"
  echo "Stack creation completed successfully."
fi
