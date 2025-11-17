#!/bin/bash

# Run Docker container locally for testing
# Usage: ./docker-run-local.sh

set -e

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "📝 Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

# Configuration
IMAGE_NAME="tstc-slack-bot-local"
CONTAINER_NAME="tstc-slack-bot-container"
PORT="${PORT:-3000}"

# Check required environment variables
if [ -z "$SLACK_BOT_TOKEN" ] || [ -z "$SLACK_SIGNING_SECRET" ]; then
    echo "❌ Error: Required environment variables are missing!"
    echo ""
    echo "Please set the following variables:"
    echo "  - SLACK_BOT_TOKEN"
    echo "  - SLACK_SIGNING_SECRET"
    echo ""
    echo "You can either:"
    echo "  1. Create a .env file (copy from env.example)"
    echo "  2. Export them in your shell:"
    echo "     export SLACK_BOT_TOKEN='your-token'"
    echo "     export SLACK_SIGNING_SECRET='your-secret'"
    exit 1
fi

echo "🐳 Building Docker image locally..."
docker build -t ${IMAGE_NAME}:latest .

echo "🛑 Stopping and removing existing container (if any)..."
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm ${CONTAINER_NAME} 2>/dev/null || true

echo "🚀 Starting container locally on port ${PORT}..."
docker run -d \
  --name ${CONTAINER_NAME} \
  -p ${PORT}:8080 \
  -e PORT=8080 \
  -e SLACK_BOT_TOKEN="${SLACK_BOT_TOKEN}" \
  -e SLACK_SIGNING_SECRET="${SLACK_SIGNING_SECRET}" \
  -e PROJECT_ID="${PROJECT_ID:-appier-airis-tstc}" \
  -e LOCATION="${LOCATION:-us-central1}" \
  -e MODEL_NAME="${MODEL_NAME:-gemini-2.5-flash}" \
  -e RAG_CORPUS_NAME="${RAG_CORPUS_NAME}" \
  ${IMAGE_NAME}:latest

echo "✅ Container started!"
echo ""
echo "📋 Container info:"
docker ps | grep ${CONTAINER_NAME}
echo ""
echo "📝 View logs:"
echo "   docker logs -f ${CONTAINER_NAME}"
echo ""
echo "🛑 Stop container:"
echo "   docker stop ${CONTAINER_NAME}"
echo ""
echo "🌐 Service should be available at:"
echo "   http://localhost:${PORT}"
echo "   http://localhost:${PORT}/health"
echo "   http://localhost:${PORT}/slack/events"

