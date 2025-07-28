#!/bin/bash
set -e

# ----------- CONFIGURATION ------------
REGION="us-east-1"
CLUSTER_NAME="dev-fuego-socks-eks"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
NAMESPACE="kube-system"  # Namespace for AWS Load Balancer Controller
MICROSERVICES_NAMESPACE="microservices"  # Dedicated namespace for microservices demo

SERVICE_ACCOUNT="aws-load-balancer-controller"
HELM_REPO_AWS="eks"
HELM_REPO_AWS_URL="https://aws.github.io/eks-charts"
HELM_REPO_BITNAMI="bitnami"
HELM_REPO_BITNAMI_URL="https://charts.bitnami.com/bitnami"

MICROSERVICES_HELM_CHART="microservices-demo"
MICROSERVICES_RELEASE_NAME="microservices-demo"

INGRESS_PATH="./scripts/dev/ingress.yaml"

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

echo "Creating IAM policy if it doesn't exist..."
POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy"
if ! aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
  aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json
else
  echo "IAM policy already exists, skipping creation."
fi

echo "Creating IAM service account for Load Balancer Controller..."
eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" \
  --namespace "$NAMESPACE" \
  --name "$SERVICE_ACCOUNT" \
  --attach-policy-arn "$POLICY_ARN" \
  --approve \
  --override-existing-serviceaccounts

echo "Adding Helm repos..."
helm repo add "$HELM_REPO_AWS" "$HELM_REPO_AWS_URL"
helm repo add "$HELM_REPO_BITNAMI" "$HELM_REPO_BITNAMI_URL"
helm repo update

echo "Installing AWS Load Balancer Controller..."
helm upgrade --install aws-load-balancer-controller "$HELM_REPO_AWS"/aws-load-balancer-controller \
  -n "$NAMESPACE" \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name="$SERVICE_ACCOUNT" \
  --set region="$REGION" \
  --wait

echo "Creating namespace $MICROSERVICES_NAMESPACE if it does not exist..."
kubectl get namespace "$MICROSERVICES_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$MICROSERVICES_NAMESPACE"

echo "Installing microservices demo Helm chart in namespace $MICROSERVICES_NAMESPACE..."
helm upgrade --install "$MICROSERVICES_RELEASE_NAME" "$HELM_REPO_BITNAMI"/"$MICROSERVICES_HELM_CHART" \
  -n "$MICROSERVICES_NAMESPACE" \
  --wait

echo "Cleaning up downloaded IAM policy file..."
rm -f iam_policy.json

echo "Applying ingress resource in namespace $MICROSERVICES_NAMESPACE..."
kubectl apply -f "$INGRESS_PATH" -n "$MICROSERVICES_NAMESPACE"

echo "All done! AWS Load Balancer Controller and microservices demo installed."
