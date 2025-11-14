#!/bin/bash

# Deploy script for Google Cloud Run
# Usage: ./deploy.sh [service-name] [region]

set -e

# Configuration
PROJECT_ID="${PROJECT_ID:-appier-airis-tstc}"
SERVICE_NAME="${1:-tstc-slack-bot}"
REGION="${2:-us-central1}"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "🚀 Deploying ${SERVICE_NAME} to Cloud Run..."
echo "   Project: ${PROJECT_ID}"
echo "   Region: ${REGION}"
echo "   Image: ${IMAGE_NAME}"

# Build the Docker image
echo "📦 Building Docker image..."
docker build -t ${IMAGE_NAME}:latest .

# Push to Google Container Registry
echo "📤 Pushing image to GCR..."
docker push ${IMAGE_NAME}:latest

# Deploy to Cloud Run
echo "🚀 Deploying to Cloud Run..."
gcloud run deploy ${SERVICE_NAME} \
  --image ${IMAGE_NAME}:latest \
  --platform managed \
  --region ${REGION} \
  --project ${PROJECT_ID} \
  --allow-unauthenticated \
  --port 8080 \
  --memory 512Mi \
  --cpu 1 \
  --timeout 300 \
  --max-instances 10 \
  --set-env-vars "PORT=8080" \
  --set-secrets "SLACK_BOT_TOKEN=slack-bot-token:latest,SLACK_SIGNING_SECRET=slack-signing-secret:latest" \
  --set-env-vars "PROJECT_ID=${PROJECT_ID},LOCATION=us-central1,MODEL_NAME=gemini-2.5-flash"

echo "✅ Deployment complete!"
echo "   Service URL: $(gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(status.url)')"

