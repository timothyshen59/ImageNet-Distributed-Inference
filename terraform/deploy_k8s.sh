#!/bin/bash
set -e
set -x

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET=$(aws s3 ls | grep imagenet-distributedinference | awk '{print $3}')

echo "Deploying to K8s..."

# Clone or pull latest code
if [ -d "ImageNet-Distributed-Inference" ]; then
  cd ImageNet-Distributed-Inference
  git pull origin main
else
  git clone https://github.com/timothyshen59/ImageNet-Distributed-Inference.git
  cd ImageNet-Distributed-Inference
fi

# Create secrets
kubectl create secret docker-registry ecr-pull-secret \
  --docker-server=$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region $REGION) \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic aws-secrets \
  --from-literal=account_id=$ACCOUNT_ID \
  --from-literal=region=$REGION \
  --from-literal=bucket_name=$BUCKET \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy
export AWS_ACCOUNT_ID=$ACCOUNT_ID
export IMAGE_TAG=latest

envsubst < k8s/fastapi-deployment.yml | kubectl apply -f -
envsubst < k8s/triton-deployment.yml  | kubectl apply -f -
kubectl apply -f k8s/fastapi-service.yml
kubectl apply -f k8s/triton-service.yml
kubectl apply -f k8s/hpa.yml
kubectl apply -f k8s/prometheus-deployment.yml
kubectl apply -f k8s/grafana-deployment.yml

echo "✅ Deployed — watching pods..."
kubectl get pods -w