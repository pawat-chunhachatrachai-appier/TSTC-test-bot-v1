#!/bin/bash

# Quick test script for Docker - builds and runs interactively
# Usage: ./docker-test.sh

set -e

IMAGE_NAME="tstc-slack-bot-local"

echo "🐳 Building Docker image..."
docker build -t ${IMAGE_NAME}:latest .

echo ""
echo "🚀 Running container interactively (Ctrl+C to stop)..."
echo "📝 Make sure you have set environment variables:"
echo "   SLACK_BOT_TOKEN, SLACK_SIGNING_SECRET, etc."
echo ""

docker run -it --rm \
  -p 3000:8080 \
  -e PORT=8080 \
  -e SLACK_BOT_TOKEN="${SLACK_BOT_TOKEN}" \
  -e SLACK_SIGNING_SECRET="${SLACK_SIGNING_SECRET}" \
  -e PROJECT_ID="${PROJECT_ID:-appier-airis-tstc}" \
  -e LOCATION="${LOCATION:-us-central1}" \
  -e MODEL_NAME="${MODEL_NAME:-gemini-2.5-flash}" \
  -e RAG_CORPUS_NAME="${RAG_CORPUS_NAME}" \
  ${IMAGE_NAME}:latest

