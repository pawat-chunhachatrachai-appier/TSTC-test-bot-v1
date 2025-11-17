#!/bin/bash

# Grant Cloud Run service account access to secrets
# Usage: ./grant-secret-access.sh [service-name] [region]

set -e

PROJECT_ID="${PROJECT_ID:-appier-airis-tstc}"
SERVICE_NAME="${1:-tstc-slack-bot}"
REGION="${2:-us-central1}"

echo "🔐 Granting secret access to Cloud Run service..."
echo "   Project: ${PROJECT_ID}"
echo "   Service: ${SERVICE_NAME}"
echo "   Region: ${REGION}"
echo ""

# Get the Cloud Run service account
echo "📋 Getting Cloud Run service account..."
SERVICE_ACCOUNT=$(gcloud run services describe ${SERVICE_NAME} \
    --region ${REGION} \
    --project ${PROJECT_ID} \
    --format 'value(spec.template.spec.serviceAccountName)' 2>/dev/null || echo "")

if [ -z "$SERVICE_ACCOUNT" ]; then
    echo "⚠️  Service not found. Using default compute service account..."
    SERVICE_ACCOUNT="${PROJECT_ID}@appspot.gserviceaccount.com"
fi

echo "   Service Account: ${SERVICE_ACCOUNT}"
echo ""

# Grant access to secrets
SECRETS=("slack-bot-token" "slack-signing-secret" "slack-default-channel")

for SECRET in "${SECRETS[@]}"; do
    if gcloud secrets describe ${SECRET} --project=${PROJECT_ID} &>/dev/null; then
        echo "🔑 Granting access to: ${SECRET}..."
        gcloud secrets add-iam-policy-binding ${SECRET} \
            --member="serviceAccount:${SERVICE_ACCOUNT}" \
            --role="roles/secretmanager.secretAccessor" \
            --project=${PROJECT_ID} \
            --quiet
        echo "   ✅ Granted access to ${SECRET}"
    else
        echo "   ⚠️  Secret ${SECRET} not found, skipping..."
    fi
done

echo ""
echo "✅ Secret access granted!"
echo ""
echo "📋 To verify:"
echo "   gcloud secrets get-iam-policy slack-bot-token --project=${PROJECT_ID}"

