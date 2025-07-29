#!/bin/bash
set -e

# ----------- PREREQUISITE CHECKS ------------
for cmd in aws eksctl helm kubectl; do
  if ! command -v $cmd >/dev/null 2>&1; then
    echo "Error: $cmd CLI is not installed or not in PATH. Please install it before running this script."
    exit 1
  fi
done

# ----------- CONFIGURATION VARIABLES ------------
REGION="us-east-1"
CLUSTER_NAME="dev-fuego-socks-eks"
NAMESPACE="kube-system"                      # Namespace for AWS Load Balancer Controller
MICROSERVICES_NAMESPACE="microservices"      # Namespace for microservices demo
SERVICE_ACCOUNT="aws-load-balancer-controller"

HELM_REPO_AWS="eks"
HELM_REPO_AWS_URL="https://aws.github.io/eks-charts"
HELM_REPO_BITNAMI="bitnami"
HELM_REPO_BITNAMI_URL="https://charts.bitnami.com/bitnami"

MICROSERVICES_HELM_CHART="microservices-demo"
MICROSERVICES_RELEASE_NAME="microservices-demo"
INGRESS_PATH="./scripts/dev/ingress.yaml"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy"

# ----------- FETCH VPC ID FROM EKS CLUSTER ------------
echo "Fetching VPC ID for EKS cluster $CLUSTER_NAME in region $REGION..."
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query "cluster.resourcesVpcConfig.vpcId" --output text)
echo "VPC ID found: $VPC_ID"

# ----------- CREATE IAM POLICY FOR AWS LOAD BALANCER CONTROLLER ------------
echo "Checking for existing IAM policy: AWSLoadBalancerControllerIAMPolicy..."
if ! aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
  echo "IAM policy not found. Downloading policy JSON and creating policy..."
  curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
  aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json || {
    echo "Warning: IAM policy creation may have failed because policy already exists or is propagating. Proceeding anyway..."
  }
  rm iam_policy.json
else
  echo "IAM policy already exists."
fi

# ----------- ASSOCIATE IAM OIDC PROVIDER WITH THE EKS CLUSTER ------------
echo "Associating IAM OIDC provider with EKS cluster for service account IAM roles..."
eksctl utils associate-iam-oidc-provider --region "$REGION" --cluster "$CLUSTER_NAME" --approve

# ----------- CREATE IAM SERVICE ACCOUNT FOR AWS LOAD BALANCER CONTROLLER ------------
echo "Creating (or updating) IAM service account for AWS Load Balancer Controller in namespace $NAMESPACE..."
eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" \
  --namespace "$NAMESPACE" \
  --name "$SERVICE_ACCOUNT" \
  --attach-policy-arn "$POLICY_ARN" \
  --approve \
  --override-existing-serviceaccounts

# ----------- ADD HELM REPOSITORIES AND UPDATE ------------
echo "Adding Helm chart repositories for AWS and Bitnami..."
helm repo add "$HELM_REPO_AWS" "$HELM_REPO_AWS_URL"
helm repo add "$HELM_REPO_BITNAMI" "$HELM_REPO_BITNAMI_URL"
helm repo update

# ----------- INSTALL AWS LOAD BALANCER CONTROLLER VIA HELM ------------
echo "Installing AWS Load Balancer Controller Helm chart..."
helm upgrade --install aws-load-balancer-controller "$HELM_REPO_AWS"/aws-load-balancer-controller \
  -n "$NAMESPACE" \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name="$SERVICE_ACCOUNT" \
  --set region="$REGION" \
  --set vpcId="$VPC_ID" \
  --wait

# ----------- ENSURE MICROSERVICES NAMESPACE EXISTS ------------
echo "Checking if microservices namespace '$MICROSERVICES_NAMESPACE' exists..."
if ! kubectl get namespace "$MICROSERVICES_NAMESPACE" >/dev/null 2>&1; then
  echo "Namespace '$MICROSERVICES_NAMESPACE' does not exist, creating..."
  kubectl create namespace "$MICROSERVICES_NAMESPACE"
else
  echo "Namespace '$MICROSERVICES_NAMESPACE' already exists."
fi

# ----------- INSTALL MICROSERVICES DEMO HELM CHART ------------
echo "Installing microservices demo Helm chart into namespace $MICROSERVICES_NAMESPACE..."
helm upgrade --install "$MICROSERVICES_RELEASE_NAME" "$HELM_REPO_BITNAMI/$MICROSERVICES_HELM_CHART" \
  -n "$MICROSERVICES_NAMESPACE" \
  --wait

# ----------- APPLY INGRESS MANIFEST TO EXPOSE MICROSERVICES ------------
echo "Applying ingress manifest to namespace $MICROSERVICES_NAMESPACE..."
kubectl apply -f "$INGRESS_PATH" -n "$MICROSERVICES_NAMESPACE"

# ----------- OUTPUT ALB DNS FOR EASY ACCESS ------------
echo "Waiting a few seconds for ingress to be provisioned..."
sleep 10
ALB_DNS=$(kubectl get ingress -n "$MICROSERVICES_NAMESPACE" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
if [ -n "$ALB_DNS" ]; then
  echo "Setup complete! Access your microservices demo at: http://$ALB_DNS"
else
  echo "Setup complete! ALB DNS name is not yet available. You can check with:\n  kubectl get ingress -n $MICROSERVICES_NAMESPACE"
fi
