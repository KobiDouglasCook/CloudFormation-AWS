#!/bin/bash
set -e

REGION="us-east-1"

echo "Listing and deleting Load Balancers..."
aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[*].LoadBalancerArn" --output text | \
xargs -n1 aws elbv2 delete-load-balancer --region $REGION --load-balancer-arn || echo "No Load Balancers found."

echo "Waiting 30s for Load Balancers to delete..."
sleep 30

echo "Listing and deleting Target Groups..."
aws elbv2 describe-target-groups --region $REGION --query "TargetGroups[*].TargetGroupArn" --output text | \
xargs -n1 aws elbv2 delete-target-group --region $REGION --target-group-arn || echo "No Target Groups found."

echo "Listing and deleting CloudFormation stacks..."
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --region $REGION \
--query "StackSummaries[?contains(StackName, 'networking') || contains(StackName, 'eksctl')].StackName" --output text | \
xargs -n1 aws cloudformation delete-stack --stack-name || echo "No relevant stacks found."

echo "Listing VPCs tagged for EKS and deleting them..."
VPC_IDS=$(aws ec2 describe-vpcs --region $REGION --filters "Name=tag:alpha.eksctl.io/cluster-name,Values=*" --query "Vpcs[*].VpcId" --output text)
for VPC_ID in $VPC_IDS; do
  echo "Deleting VPC: $VPC_ID"
  aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION || echo "Failed to delete VPC $VPC_ID"
done

echo "Cleanup Complete."
