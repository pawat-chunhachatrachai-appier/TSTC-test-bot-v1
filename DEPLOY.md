# Deploying to Google Cloud Run

This guide explains how to deploy the TSTC Slack Bot to Google Cloud Run.

## Prerequisites

1. **Google Cloud SDK** installed and authenticated:
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Docker** installed and running

3. **Required APIs enabled:**
   ```bash
   gcloud services enable run.googleapis.com
   gcloud services enable cloudbuild.googleapis.com
   gcloud services enable containerregistry.googleapis.com
   gcloud services enable aiplatform.googleapis.com
   ```

4. **IAM Permissions:**
   - Cloud Run Admin
   - Service Account User
   - Cloud Build Service Account

## Option 1: Quick Deploy Script

1. Make the script executable:
   ```bash
   chmod +x deploy.sh
   ```

2. Set your project ID:
   ```bash
   export PROJECT_ID="appier-airis-tstc"
   ```

3. Run the deploy script:
   ```bash
   ./deploy.sh
   ```

   Or with custom service name and region:
   ```bash
   ./deploy.sh my-slack-bot us-central1
   ```

## Option 2: Manual Deployment

### Step 1: Build Docker Image

```bash
# Set your project ID
export PROJECT_ID="appier-airis-tstc"
export SERVICE_NAME="tstc-slack-bot"
export REGION="us-central1"

# Build the image
docker build -t gcr.io/${PROJECT_ID}/${SERVICE_NAME}:latest .
```

### Step 2: Push to Google Container Registry

```bash
# Configure Docker to use gcloud as a credential helper
gcloud auth configure-docker

# Push the image
docker push gcr.io/${PROJECT_ID}/${SERVICE_NAME}:latest
```

### Step 3: Deploy to Cloud Run

```bash
gcloud run deploy ${SERVICE_NAME} \
  --image gcr.io/${PROJECT_ID}/${SERVICE_NAME}:latest \
  --platform managed \
  --region ${REGION} \
  --project ${PROJECT_ID} \
  --allow-unauthenticated \
  --port 8080 \
  --memory 512Mi \
  --cpu 1 \
  --timeout 300 \
  --max-instances 10
```

### Step 4: Set Environment Variables

```bash
gcloud run services update ${SERVICE_NAME} \
  --region ${REGION} \
  --update-env-vars "PROJECT_ID=appier-airis-tstc" \
  --update-env-vars "LOCATION=us-central1" \
  --update-env-vars "MODEL_NAME=gemini-2.5-flash" \
  --update-env-vars "RAG_CORPUS_NAME=projects/appier-airis-tstc/locations/asia-east1/ragCorpora/4611686018427387904"
```

### Step 5: Set Secrets (Recommended)

For security, store sensitive values in Secret Manager:

```bash
# Create secrets
echo -n "xoxb-your-token" | gcloud secrets create slack-bot-token --data-file=-
echo -n "your-signing-secret" | gcloud secrets create slack-signing-secret --data-file=-

# Grant Cloud Run access to secrets
gcloud secrets add-iam-policy-binding slack-bot-token \
  --member="serviceAccount:YOUR_SERVICE_ACCOUNT@YOUR_PROJECT.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding slack-signing-secret \
  --member="serviceAccount:YOUR_SERVICE_ACCOUNT@YOUR_PROJECT.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Update service to use secrets
gcloud run services update ${SERVICE_NAME} \
  --region ${REGION} \
  --update-secrets "SLACK_BOT_TOKEN=slack-bot-token:latest,SLACK_SIGNING_SECRET=slack-signing-secret:latest"
```

## Option 3: Using Cloud Build (CI/CD)

1. **Enable Cloud Build API:**
   ```bash
   gcloud services enable cloudbuild.googleapis.com
   ```

2. **Submit build:**
   ```bash
   gcloud builds submit --config cloudbuild.yaml
   ```

   Or set up a trigger for automatic deployments on git push.

## Configuration

### Environment Variables

Set these in Cloud Run:

- `SLACK_BOT_TOKEN` - Your Slack bot token (use Secret Manager)
- `SLACK_SIGNING_SECRET` - Your Slack signing secret (use Secret Manager)
- `PROJECT_ID` - Your GCP project ID
- `LOCATION` - Region for Vertex AI (e.g., `us-central1`)
- `MODEL_NAME` - Gemini model name (e.g., `gemini-2.5-flash`)
- `RAG_CORPUS_NAME` - Full RAG corpus resource name
- `PORT` - Port number (default: 8080, Cloud Run sets this automatically)

### Service Account

Cloud Run uses a service account. Make sure it has:

- `roles/aiplatform.user` - For Vertex AI access
- `roles/secretmanager.secretAccessor` - If using Secret Manager
- `roles/storage.objectViewer` - If accessing GCS files

```bash
# Get the service account email
SERVICE_ACCOUNT=$(gcloud run services describe ${SERVICE_NAME} \
  --region ${REGION} \
  --format 'value(spec.template.spec.serviceAccountName)')

# Grant permissions
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/aiplatform.user"
```

## Update Slack Webhook URL

After deployment, get your Cloud Run URL:

```bash
gcloud run services describe ${SERVICE_NAME} \
  --region ${REGION} \
  --format 'value(status.url)'
```

Update your Slack app's Event Subscriptions Request URL to:
```
https://YOUR-SERVICE-URL/slack/events
```

## Monitoring

View logs:
```bash
gcloud run services logs read ${SERVICE_NAME} --region ${REGION}
```

Or in the Cloud Console:
- Go to Cloud Run → Your Service → Logs

## Troubleshooting

### Container fails to start

- Check logs: `gcloud run services logs read ${SERVICE_NAME} --region ${REGION}`
- Verify environment variables are set correctly
- Check that the service account has required permissions

### Authentication errors

- Ensure Application Default Credentials are available (Cloud Run provides this automatically)
- Verify service account has `roles/aiplatform.user`

### Model not found errors

- Check that `LOCATION` is set to a region with Gemini models
- Verify `MODEL_NAME` is correct for that region

### Slack webhook not working

- Verify the Request URL in Slack app settings
- Check that the service is publicly accessible (`--allow-unauthenticated`)
- Check Cloud Run logs for errors

## Scaling

Cloud Run automatically scales based on traffic. You can set limits:

```bash
gcloud run services update ${SERVICE_NAME} \
  --region ${REGION} \
  --min-instances 0 \
  --max-instances 10 \
  --concurrency 80 \
  --cpu 1 \
  --memory 512Mi
```

## Cost Optimization

- Set `--min-instances 0` to scale to zero when not in use
- Adjust `--max-instances` based on expected traffic
- Use appropriate CPU and memory settings

## Next Steps

- Set up Cloud Build triggers for automatic deployments
- Configure monitoring and alerting
- Set up custom domain (optional)
- Enable Cloud CDN for better performance (optional)

