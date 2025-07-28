#!/bin/bash
set -e

# ----------- CONFIGURATION ------------
REGION="us-east-1"
CLUSTER_NAME="dev-fuego-socks-eks"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
NAMESPACE="kube-system"
SERVICE_ACCOUNT="aws-load-balancer-controller"
HELM_REPO_NAME="eks"
HELM_REPO_URL="https://aws.github.io/eks-charts"
MICROSERVICES_HELM_REPO="https://charts.bitnami.com/bitnami"
MICROSERVICES_HELM_CHART="microservices-demo"
MICROSERVICES_RELEASE_NAME="microservices-demo"

# ----------- FUNCTIONS ------------
function check_command() {
  command -v "$1" >/dev/null 2>&1 || { echo >&2 "Error: $1 is not installed."; exit 1; }
}

# ----------- PRE-CHECKS ------------
check_command aws
check_command kubectl
check_command helm

echo "Updating kubeconfig for cluster $CLUSTER_NAME..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

echo "Associating IAM OIDC provider..."
eksctl utils associate-iam-oidc-provider \
  --region "$REGION" \
  --cluster "$CLUSTER_NAME" \
  --approve

echo "Downloading IAM policy for AWS Load Balancer Controller..."
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

echo "Creating IAM policy..."
POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy"
aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1 || \
  aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json

echo "Creating IAM service account for Load Balancer Controller..."
eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" \
  --namespace "$NAMESPACE" \
  --name "$SERVICE_ACCOUNT" \
  --attach-policy-arn "$POLICY_ARN" \
  --approve \
  --override-existing-serviceaccounts

echo "Adding Helm repo for AWS Load Balancer Controller..."
helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL"
helm repo update

echo "Installing AWS Load Balancer Controller..."
helm upgrade --install aws-load-balancer-controller "$HELM_REPO_NAME"/aws-load-balancer-controller \
  -n "$NAMESPACE" \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name="$SERVICE_ACCOUNT" \
  --set region="$REGION" \
  --wait

echo "Adding Helm repo for microservices demo..."
helm repo add bitnami "$MICROSERVICES_HELM_REPO"
helm repo update

echo "Installing microservices demo Helm chart..."
helm upgrade --install "$MICROSERVICES_RELEASE_NAME" bitnami/"$MICROSERVICES_HELM_CHART" --wait

echo "Cleanup: removing downloaded IAM policy file"
rm -f iam_policy.json

echo "Applying Ingress resource to expose the microservices demo..."
kubectl apply -f ingress.yaml

echo "All done! Your AWS Load Balancer Controller and microservices demo are installed."
