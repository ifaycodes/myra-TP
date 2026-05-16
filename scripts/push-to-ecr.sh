#!/bin/bash

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="eu-west-2"
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

# Create repositories
echo "Creating ECR repositories..."
aws ecr create-repository --repository-name ingestion --region $REGION 2>/dev/null || echo "ingestion repo already exists"
aws ecr create-repository --repository-name validation --region $REGION 2>/dev/null || echo "validation repo already exists"
aws ecr create-repository --repository-name processing --region $REGION 2>/dev/null || echo "processing repo already exists"

# Tag images
echo "Tagging images..."
docker tag ingestion:latest $ECR_URI/ingestion:latest
docker tag validation:latest $ECR_URI/validation:latest
docker tag processing:latest $ECR_URI/processing:latest

# Push images
echo "Pushing images to ECR..."
docker push $ECR_URI/ingestion:latest
docker push $ECR_URI/validation:latest
docker push $ECR_URI/processing:latest

echo ""
echo "Done."

cat > ../terraform/terraform.tfvars <<EOF
ingestion_image  = "$ECR_URI/ingestion:latest"
validation_image = "$ECR_URI/validation:latest"
processing_image = "$ECR_URI/processing:latest"
EOF