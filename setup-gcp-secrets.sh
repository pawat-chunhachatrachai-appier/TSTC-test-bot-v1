#!/bin/bash

# Script to sync .env file credentials to GCP Secret Manager
# Usage: ./setup-gcp-secrets.sh

set -e

# Configuration
PROJECT_ID="${PROJECT_ID:-appier-airis-tstc}"
REGION="${REGION:-us-central1}"

echo "🔐 Setting up GCP Secret Manager for credentials..."
echo "   Project: ${PROJECT_ID}"
echo "   Region: ${REGION}"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo ""
    echo "Please create a .env file first:"
    echo "  1. Copy env.example to .env: cp env.example .env"
    echo "  2. Fill in your credentials in .env"
    echo "  3. Run this script again"
    exit 1
fi

# Load .env file
echo "📝 Loading credentials from .env file..."
export $(grep -v '^#' .env | grep -v '^$' | xargs)

# Check required variables
if [ -z "$SLACK_BOT_TOKEN" ] || [ -z "$SLACK_SIGNING_SECRET" ]; then
    echo "❌ Error: Required credentials are missing in .env file!"
    echo "   Required: SLACK_BOT_TOKEN, SLACK_SIGNING_SECRET"
    exit 1
fi

echo "✅ Found required credentials in .env"
echo ""

# Enable Secret Manager API
echo "🔧 Enabling Secret Manager API..."
gcloud services enable secretmanager.googleapis.com --project=${PROJECT_ID} 2>/dev/null || true

# Function to create or update secret
create_or_update_secret() {
    local SECRET_NAME=$1
    local SECRET_VALUE=$2
    
    echo "   Processing: ${SECRET_NAME}..."
    
    # Check if secret exists
    if gcloud secrets describe ${SECRET_NAME} --project=${PROJECT_ID} &>/dev/null; then
        echo "   ⚠️  Secret '${SECRET_NAME}' already exists. Updating..."
        echo -n "${SECRET_VALUE}" | gcloud secrets versions add ${SECRET_NAME} \
            --data-file=- \
            --project=${PROJECT_ID}
        echo "   ✅ Updated secret: ${SECRET_NAME}"
    else
        echo "   📝 Creating new secret: ${SECRET_NAME}..."
        echo -n "${SECRET_VALUE}" | gcloud secrets create ${SECRET_NAME} \
            --data-file=- \
            --project=${PROJECT_ID} \
            --replication-policy="automatic"
        echo "   ✅ Created secret: ${SECRET_NAME}"
    fi
}

# Create/update secrets
echo "📦 Creating/updating secrets in Secret Manager..."
create_or_update_secret "slack-bot-token" "${SLACK_BOT_TOKEN}"
create_or_update_secret "slack-signing-secret" "${SLACK_SIGNING_SECRET}"

# Optional: SLACK_DEFAULT_CHANNEL
if [ -n "$SLACK_DEFAULT_CHANNEL" ]; then
    create_or_update_secret "slack-default-channel" "${SLACK_DEFAULT_CHANNEL}"
fi

echo ""
echo "✅ Secrets have been synced to GCP Secret Manager!"
echo ""
echo "📋 Next steps:"
echo "   1. Grant Cloud Run service account access to secrets:"
echo "      ./grant-secret-access.sh"
echo ""
echo "   2. Deploy your service:"
echo "      ./deploy.sh"
echo ""
echo "🔍 To view secrets:"
echo "   gcloud secrets list --project=${PROJECT_ID}"
echo ""
echo "⚠️  Note: Your .env file is NOT pushed to git (it's in .gitignore)"
echo "   Secrets are now safely stored in GCP Secret Manager"

