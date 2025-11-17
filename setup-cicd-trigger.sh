#!/bin/bash

# Setup Cloud Build trigger for GitHub repository
# Usage: ./setup-cicd-trigger.sh [github-owner] [github-repo] [project-id] [branch]

set -e

# Configuration
GITHUB_OWNER="${1}"
GITHUB_REPO="${2}"
PROJECT_ID="${3:-appier-airis-tstc}"
BRANCH="${4:-master}"
TRIGGER_NAME="tstc-slack-bot-deploy"
REGION="us-central1"

# Check required parameters
if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ]; then
    echo "❌ Error: GitHub owner and repository are required!"
    echo ""
    echo "Usage: ./setup-cicd-trigger.sh [github-owner] [github-repo] [project-id] [branch]"
    echo ""
    echo "Example:"
    echo "  ./setup-cicd-trigger.sh myusername tstc-slack-bot appier-airis-tstc master"
    echo ""
    exit 1
fi

echo "🚀 Setting up Cloud Build trigger for CI/CD..."
echo "   GitHub: ${GITHUB_OWNER}/${GITHUB_REPO}"
echo "   Branch: ${BRANCH}"
echo "   Project: ${PROJECT_ID}"
echo "   Trigger Name: ${TRIGGER_NAME}"
echo ""

# Check if Cloud Build API is enabled
echo "🔧 Checking Cloud Build API..."
if ! gcloud services list --enabled --project=${PROJECT_ID} 2>/dev/null | grep -q cloudbuild.googleapis.com; then
    echo "   Enabling Cloud Build API..."
    gcloud services enable cloudbuild.googleapis.com --project=${PROJECT_ID}
    echo "   ✅ Cloud Build API enabled"
else
    echo "   ✅ Cloud Build API already enabled"
fi

# Check if GitHub connection exists
echo ""
echo "🔍 Checking GitHub connection..."
CONNECTION_NAME="github-connection"

# Try to get existing connection
if gcloud builds connections list --region=${REGION} --project=${PROJECT_ID} 2>/dev/null | grep -q "${CONNECTION_NAME}"; then
    echo "   ✅ GitHub connection exists: ${CONNECTION_NAME}"
else
    echo "   ⚠️  GitHub connection not found. You need to create it first:"
    echo ""
    echo "   1. Go to Cloud Console → Cloud Build → Connections"
    echo "   2. Create a new GitHub connection"
    echo "   3. Authorize and install the GitHub app"
    echo ""
    echo "   Or use the command:"
    echo "   gcloud builds connections create github \\"
    echo "     --region=${REGION} \\"
    echo "     --project=${PROJECT_ID}"
    echo ""
    read -p "   Press Enter after creating the connection, or Ctrl+C to cancel..."
fi

# Get the connection name (use the first available or specified one)
CONNECTION=$(gcloud builds connections list --region=${REGION} --project=${PROJECT_ID} --format="value(name)" 2>/dev/null | head -1 || echo "")

if [ -z "$CONNECTION" ]; then
    echo "❌ Error: No GitHub connection found!"
    echo "   Please create a GitHub connection first (see instructions above)"
    exit 1
fi

echo "   Using connection: ${CONNECTION}"
echo ""

# Check if trigger already exists
echo "🔍 Checking if trigger already exists..."
if gcloud builds triggers describe ${TRIGGER_NAME} --project=${PROJECT_ID} &>/dev/null; then
    echo "   ⚠️  Trigger '${TRIGGER_NAME}' already exists"
    read -p "   Do you want to update it? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "   Cancelled."
        exit 0
    fi
    echo "   Updating trigger..."
    UPDATE_FLAG="--update"
else
    echo "   Creating new trigger..."
    UPDATE_FLAG=""
fi

# Create or update the trigger
echo ""
echo "📝 Creating/updating Cloud Build trigger..."

# Build substitution variables
SUBSTITUTIONS="_SERVICE_NAME=tstc-slack-bot,_REGION=${REGION},_LOCATION=us-central1,_MODEL_NAME=gemini-2.5-flash,_RAG_CORPUS_NAME=projects/appier-airis-tstc/locations/asia-east1/ragCorpora/4611686018427387904"

if [ -n "$UPDATE_FLAG" ]; then
    # Update existing trigger
    gcloud builds triggers update github ${TRIGGER_NAME} \
      --project=${PROJECT_ID} \
      --region=${REGION} \
      --repo-name=${GITHUB_REPO} \
      --repo-owner=${GITHUB_OWNER} \
      --branch-pattern="^${BRANCH}$" \
      --build-config="cloudbuild.yaml" \
      --substitutions="${SUBSTITUTIONS}" \
      --description="Auto-deploy TSTC Slack Bot on push to ${BRANCH}" \
      --quiet
else
    # Create new trigger
    gcloud builds triggers create github \
      --name=${TRIGGER_NAME} \
      --project=${PROJECT_ID} \
      --region=${REGION} \
      --repo-name=${GITHUB_REPO} \
      --repo-owner=${GITHUB_OWNER} \
      --branch-pattern="^${BRANCH}$" \
      --build-config="cloudbuild.yaml" \
      --substitutions="${SUBSTITUTIONS}" \
      --description="Auto-deploy TSTC Slack Bot on push to ${BRANCH}"
fi

echo ""
echo "✅ Cloud Build trigger configured!"
echo ""
echo "📋 Trigger details:"
echo "   Name: ${TRIGGER_NAME}"
echo "   Repository: ${GITHUB_OWNER}/${GITHUB_REPO}"
echo "   Branch: ${BRANCH}"
echo "   Config: cloudbuild.yaml"
echo ""
echo "🔍 To view triggers:"
echo "   gcloud builds triggers list --project=${PROJECT_ID}"
echo ""
echo "📝 Next steps:"
echo "   1. Make sure Cloud Build service account has permissions:"
echo "      ./setup-cloud-build-sa.sh ${PROJECT_ID}"
echo ""
echo "   2. Make sure secrets exist in Secret Manager:"
echo "      ./setup-gcp-secrets.sh"
echo ""
echo "   3. Push to ${BRANCH} branch to trigger deployment:"
echo "      git push origin ${BRANCH}"
echo ""
echo "   4. Monitor builds:"
echo "      gcloud builds list --project=${PROJECT_ID}"

