#!/bin/bash

# Deploy script for Google Cloud Run
# Usage: ./deploy.sh [service-name] [region]

set -e

# Load environment variables from .env file if it exists (for PROJECT_ID, LOCATION, etc.)
if [ -f .env ]; then
    export $(grep -v '^#' .env | grep -v '^$' | xargs)
fi

# Configuration
PROJECT_ID="${PROJECT_ID:-appier-airis-tstc}"
SERVICE_NAME="${1:-tstc-slack-bot}"
REGION="${2:-us-central1}"
LOCATION="${LOCATION:-us-central1}"
MODEL_NAME="${MODEL_NAME:-gemini-2.5-flash}"
RAG_CORPUS_NAME="${RAG_CORPUS_NAME:-projects/appier-airis-tstc/locations/asia-east1/ragCorpora/4611686018427387904}"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "🚀 Deploying ${SERVICE_NAME} to Cloud Run..."
echo "   Project: ${PROJECT_ID}"
echo "   Region: ${REGION}"
echo "   Image: ${IMAGE_NAME}"
echo ""

# Check if secrets exist
echo "🔍 Checking if secrets exist in Secret Manager..."
if ! gcloud secrets describe slack-bot-token --project=${PROJECT_ID} &>/dev/null; then
    echo "❌ Error: Secret 'slack-bot-token' not found in Secret Manager!"
    echo ""
    echo "Please run first:"
    echo "   ./setup-gcp-secrets.sh"
    exit 1
fi

if ! gcloud secrets describe slack-signing-secret --project=${PROJECT_ID} &>/dev/null; then
    echo "❌ Error: Secret 'slack-signing-secret' not found in Secret Manager!"
    echo ""
    echo "Please run first:"
    echo "   ./setup-gcp-secrets.sh"
    exit 1
fi

echo "✅ Secrets found in Secret Manager"
echo ""

# Build the Docker image
echo "📦 Building Docker image..."
docker build -t ${IMAGE_NAME}:latest .

# Push to Google Container Registry
echo "📤 Pushing image to GCR..."
docker push ${IMAGE_NAME}:latest

# Build secrets string
SECRETS_STRING="SLACK_BOT_TOKEN=slack-bot-token:latest,SLACK_SIGNING_SECRET=slack-signing-secret:latest"
if gcloud secrets describe slack-default-channel --project=${PROJECT_ID} &>/dev/null; then
    SECRETS_STRING="${SECRETS_STRING},SLACK_DEFAULT_CHANNEL=slack-default-channel:latest"
fi

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
  --set-env-vars "PORT=8080,PROJECT_ID=${PROJECT_ID},LOCATION=${LOCATION},MODEL_NAME=${MODEL_NAME},RAG_CORPUS_NAME=${RAG_CORPUS_NAME}" \
  --set-secrets "${SECRETS_STRING}"

echo ""
echo "✅ Deployment complete!"
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --region ${REGION} --project ${PROJECT_ID} --format 'value(status.url)' 2>/dev/null || echo "N/A")
echo "   Service URL: ${SERVICE_URL}"
echo ""
echo "📋 Next steps:"
echo "   1. Grant secret access (if not done already):"
echo "      ./grant-secret-access.sh ${SERVICE_NAME} ${REGION}"
echo ""
echo "   2. Update Slack webhook URL to:"
echo "      ${SERVICE_URL}/slack/events"

