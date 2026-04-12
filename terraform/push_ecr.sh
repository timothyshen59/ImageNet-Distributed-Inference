#!/bin/bash
#Push Image to AWS ECR for Deployment 

set -e
set -x

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL=$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
REPO_NAME="distributedinference"
IMAGE_TAG=${1:-latest}

echo "Building and pushing to ECR..."

# Create ECR repo if not exists
aws ecr describe-repositories --repository-names $REPO_NAME --region $REGION --no-cli-pager 2>/dev/null || \
  aws ecr create-repository --repository-name $REPO_NAME --region $REGION --no-cli-pager

# Login to ECR
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin $ECR_URL

# Build image
cd ..
docker buildx build --platform linux/amd64 -t $REPO_NAME:latest --load .

# Tag + push
docker tag $REPO_NAME:latest $ECR_URL/$REPO_NAME:$IMAGE_TAG
docker tag $REPO_NAME:latest $ECR_URL/$REPO_NAME:latest
docker push $ECR_URL/$REPO_NAME:$IMAGE_TAG
docker push $ECR_URL/$REPO_NAME:latest

echo "✅ Pushed $ECR_URL/$REPO_NAME:$IMAGE_TAG"