#!/bin/bash

# Create a service account for deployment with all required permissions
# Usage: ./create-deployer-sa.sh [service-account-name] [project-id]

set -e

SA_NAME="${1:-deployer}"
PROJECT_ID="${2:-appier-airis-tstc}"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "🔐 Creating deployment service account..."
echo "   Name: ${SA_NAME}"
echo "   Email: ${SA_EMAIL}"
echo "   Project: ${PROJECT_ID}"
echo ""

# Create service account
echo "📝 Creating service account..."
gcloud iam service-accounts create ${SA_NAME} \
  --display-name="Deployment Service Account" \
  --description="Service account for deploying TSTC Slack Bot" \
  --project=${PROJECT_ID} 2>/dev/null && echo "   ✅ Created" || echo "   ⚠️  Already exists"

# Grant required roles
echo ""
echo "🔑 Granting IAM roles..."

ROLES=(
  "roles/secretmanager.admin"
  "roles/run.admin"
  "roles/storage.admin"
  "roles/serviceusage.serviceUsageAdmin"
)

for ROLE in "${ROLES[@]}"; do
    echo "   Granting ${ROLE}..."
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
      --member="serviceAccount:${SA_EMAIL}" \
      --role="${ROLE}" \
      --quiet
done

echo ""
echo "✅ Service account setup complete!"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Create and download a key file:"
echo "   gcloud iam service-accounts keys create deployer-key.json \\"
echo "     --iam-account=${SA_EMAIL} \\"
echo "     --project=${PROJECT_ID}"
echo ""
echo "2. Authenticate with the service account:"
echo "   export GOOGLE_APPLICATION_CREDENTIALS=\"./deployer-key.json\""
echo "   gcloud auth activate-service-account --key-file=./deployer-key.json"
echo ""
echo "3. Set the project:"
echo "   gcloud config set project ${PROJECT_ID}"
echo ""
echo "4. Run your deployment scripts:"
echo "   ./setup-gcp-secrets.sh"
echo "   ./deploy.sh"
echo "   ./grant-secret-access.sh"
echo ""
echo "⚠️  Security:"
echo "   - Add 'deployer-key.json' to .gitignore"
echo "   - Store key file securely"
echo "   - Rotate keys regularly"

