#!/bin/bash

# Setup Cloud Build service account with required permissions
# Usage: ./setup-cloud-build-sa.sh [project-id]

set -e

PROJECT_ID="${1:-appier-airis-tstc}"

echo "🔐 Setting up Cloud Build service account permissions..."
echo "   Project: ${PROJECT_ID}"
echo ""

# Get the Cloud Build service account email
CLOUD_BUILD_SA="${PROJECT_ID}@cloudbuild.gserviceaccount.com"

echo "📋 Cloud Build Service Account: ${CLOUD_BUILD_SA}"
echo ""

# Required roles for Cloud Build to deploy to Cloud Run
ROLES=(
  "roles/run.admin"
  "roles/iam.serviceAccountUser"
  "roles/storage.admin"
  "roles/secretmanager.secretAccessor"
)

echo "🔑 Granting IAM roles to Cloud Build service account..."

for ROLE in "${ROLES[@]}"; do
    echo "   Granting ${ROLE}..."
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
      --member="serviceAccount:${CLOUD_BUILD_SA}" \
      --role="${ROLE}" \
      --quiet || echo "   ⚠️  Failed to grant ${ROLE} (may already be granted)"
done

echo ""
echo "✅ Cloud Build service account permissions configured!"
echo ""
echo "📋 To verify permissions:"
echo "   gcloud projects get-iam-policy ${PROJECT_ID} \\"
echo "     --flatten='bindings[].members' \\"
echo "     --filter='bindings.members:serviceAccount:${CLOUD_BUILD_SA}' \\"
echo "     --format='table(bindings.role)'"
echo ""
echo "📝 Note: Cloud Build service account also needs access to secrets."
echo "   If secrets don't exist yet, create them first:"
echo "   ./setup-gcp-secrets.sh"

