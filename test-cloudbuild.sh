#!/bin/bash

# Test Cloud Build configuration locally
# Usage: ./test-cloudbuild.sh [project-id]

set -e

PROJECT_ID="${1:-appier-airis-tstc}"

echo "🧪 Testing Cloud Build configuration..."
echo "   Project: ${PROJECT_ID}"
echo ""

# Check if cloudbuild.yaml exists
if [ ! -f cloudbuild.yaml ]; then
    echo "❌ Error: cloudbuild.yaml not found!"
    exit 1
fi

echo "✅ Found cloudbuild.yaml"
echo ""

# Validate YAML syntax (basic check)
echo "🔍 Validating cloudbuild.yaml syntax..."
if command -v yq &> /dev/null; then
    yq eval '.' cloudbuild.yaml > /dev/null && echo "   ✅ YAML syntax is valid"
else
    echo "   ⚠️  yq not installed, skipping YAML validation"
    echo "   Install with: brew install yq (macOS) or apt-get install yq (Linux)"
fi

echo ""
echo "📋 Cloud Build configuration summary:"
echo ""

# Extract key information from cloudbuild.yaml
if command -v yq &> /dev/null; then
    echo "   Service Name: $(yq eval '.substitutions._SERVICE_NAME' cloudbuild.yaml)"
    echo "   Region: $(yq eval '.substitutions._REGION' cloudbuild.yaml)"
    echo "   Model: $(yq eval '.substitutions._MODEL_NAME' cloudbuild.yaml)"
    echo "   Steps: $(yq eval '.steps | length' cloudbuild.yaml)"
    echo "   Images: $(yq eval '.images | length' cloudbuild.yaml)"
else
    echo "   (Install yq for detailed analysis)"
fi

echo ""
echo "🚀 To test the build, run:"
echo "   gcloud builds submit --config cloudbuild.yaml --project=${PROJECT_ID}"
echo ""
echo "   Or with substitutions:"
echo "   gcloud builds submit --config cloudbuild.yaml \\"
echo "     --substitutions=_SERVICE_NAME=tstc-slack-bot,_REGION=us-central1 \\"
echo "     --project=${PROJECT_ID}"
echo ""
echo "📝 Note: This will actually build and deploy. Use with caution!"
echo ""
read -p "   Do you want to run a test build now? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 Starting test build..."
    gcloud builds submit --config cloudbuild.yaml --project=${PROJECT_ID}
    echo ""
    echo "✅ Test build completed!"
    echo ""
    echo "🔍 View build logs:"
    echo "   gcloud builds list --project=${PROJECT_ID} --limit=1"
else
    echo "   Skipped test build."
fi

