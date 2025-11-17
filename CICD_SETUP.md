# CI/CD Pipeline Setup Guide

This guide explains how to set up a complete CI/CD pipeline for the TSTC Slack Bot using Google Cloud Build and Cloud Run.

## Overview

The CI/CD pipeline automatically:
1. Builds Docker images when code is pushed to GitHub
2. Pushes images to Google Container Registry
3. Deploys to Cloud Run
4. Uses Secret Manager for secure credential management

## Prerequisites

1. **Google Cloud Project** with billing enabled
2. **GitHub repository** with your code
3. **Required APIs enabled:**
   ```bash
   gcloud services enable cloudbuild.googleapis.com
   gcloud services enable run.googleapis.com
   gcloud services enable secretmanager.googleapis.com
   gcloud services enable containerregistry.googleapis.com
   ```

4. **IAM Permissions:**
   - Cloud Build Admin
   - Cloud Run Admin
   - Secret Manager Admin (for initial setup)

## Step-by-Step Setup

### Step 1: Set Up Secrets in Secret Manager

Before setting up CI/CD, ensure your secrets are stored in Secret Manager:

```bash
./setup-gcp-secrets.sh
```

This creates:
- `slack-bot-token`
- `slack-signing-secret`
- `slack-default-channel` (optional)

### Step 2: Configure Cloud Build Service Account

Grant the Cloud Build service account necessary permissions:

```bash
./setup-cloud-build-sa.sh [project-id]
```

This grants:
- `roles/run.admin` - Deploy to Cloud Run
- `roles/iam.serviceAccountUser` - Use service accounts
- `roles/storage.admin` - Push to Container Registry
- `roles/secretmanager.secretAccessor` - Access secrets

### Step 3: Create GitHub Connection

1. **Via Cloud Console:**
   - Go to [Cloud Build → Connections](https://console.cloud.google.com/cloud-build/connections)
   - Click "Create Connection"
   - Select "GitHub"
   - Authorize and install the GitHub app
   - Select your repository

2. **Via Command Line:**
   ```bash
   gcloud builds connections create github \
     --region=us-central1 \
     --project=appier-airis-tstc
   ```
   
   Then follow the prompts to authorize GitHub.

### Step 4: Create Cloud Build Trigger

Create a trigger that automatically builds and deploys on git push:

```bash
./setup-cicd-trigger.sh [github-owner] [github-repo] [project-id] [branch]
```

Example:
```bash
./setup-cicd-trigger.sh myusername tstc-slack-bot appier-airis-tstc master
```

This creates a trigger that:
- Monitors the `master` branch
- Triggers on every push
- Uses `cloudbuild.yaml` for build configuration
- Deploys to Cloud Run automatically

### Step 5: Grant Cloud Run Service Account Access to Secrets

After the first deployment, grant the Cloud Run service account access to secrets:

```bash
./grant-secret-access.sh tstc-slack-bot us-central1
```

## Testing the Pipeline

### Test Cloud Build Configuration

Validate your `cloudbuild.yaml`:

```bash
./test-cloudbuild.sh [project-id]
```

### Manual Build Test

Test the build process manually:

```bash
gcloud builds submit --config cloudbuild.yaml --project=appier-airis-tstc
```

### Trigger a Build

Push to your monitored branch:

```bash
git push origin master
```

The trigger will automatically start a build. Monitor it:

```bash
gcloud builds list --project=appier-airis-tstc --limit=5
```

## Configuration

### cloudbuild.yaml

The `cloudbuild.yaml` file uses substitution variables for flexibility:

- `_SERVICE_NAME` - Cloud Run service name (default: `tstc-slack-bot`)
- `_REGION` - Cloud Run region (default: `us-central1`)
- `_LOCATION` - Vertex AI location (default: `us-central1`)
- `_MODEL_NAME` - Gemini model name (default: `gemini-2.5-flash`)
- `_RAG_CORPUS_NAME` - RAG corpus resource name
- `_MEMORY` - Container memory (default: `512Mi`)
- `_CPU` - Number of CPUs (default: `1`)
- `_TIMEOUT` - Request timeout (default: `300`)
- `_MAX_INSTANCES` - Max instances (default: `10`)

### Customizing Substitutions

You can override substitutions when creating triggers:

```bash
gcloud builds triggers create github \
  --name=my-trigger \
  --substitutions=_SERVICE_NAME=my-service,_REGION=asia-east1
```

Or in the Cloud Console when creating/editing triggers.

## Monitoring and Troubleshooting

### View Build Logs

```bash
# List recent builds
gcloud builds list --project=appier-airis-tstc --limit=10

# View specific build
gcloud builds log [BUILD_ID] --project=appier-airis-tstc

# Stream logs
gcloud builds log --stream --project=appier-airis-tstc
```

### View Cloud Run Logs

```bash
gcloud run services logs read tstc-slack-bot \
  --region=us-central1 \
  --project=appier-airis-tstc
```

### Common Issues

#### Build Fails: Permission Denied

**Problem:** Cloud Build service account lacks permissions.

**Solution:**
```bash
./setup-cloud-build-sa.sh [project-id]
```

#### Deployment Fails: Secret Not Found

**Problem:** Secrets don't exist or Cloud Run service account can't access them.

**Solution:**
1. Create secrets: `./setup-gcp-secrets.sh`
2. Grant access: `./grant-secret-access.sh [service-name] [region]`

#### Trigger Not Firing

**Problem:** GitHub connection not properly configured.

**Solution:**
1. Check connection status in Cloud Console
2. Verify repository and branch in trigger configuration
3. Check GitHub app installation and permissions

#### Build Timeout

**Problem:** Build takes too long.

**Solution:**
- Increase timeout in `cloudbuild.yaml` (currently 1200s)
- Optimize Dockerfile build steps
- Use build cache

## Advanced Configuration

### Multiple Environments

Create separate triggers for different environments:

```bash
# Production trigger (master branch)
./setup-cicd-trigger.sh myusername tstc-slack-bot appier-airis-tstc master

# Staging trigger (develop branch) - with different substitutions
gcloud builds triggers create github \
  --name=tstc-slack-bot-staging \
  --repo-name=tstc-slack-bot \
  --repo-owner=myusername \
  --branch-pattern="^develop$" \
  --build-config="cloudbuild.yaml" \
  --substitutions="_SERVICE_NAME=tstc-slack-bot-staging,_REGION=us-central1"
```

### Build Notifications

Set up build notifications:

```bash
# Enable Pub/Sub notifications
gcloud builds triggers update [TRIGGER_NAME] \
  --project=appier-airis-tstc \
  --pubsub-config=topic=projects/appier-airis-tstc/topics/build-notifications
```

### Build Approvals

Require manual approval before deployment:

1. Create an approval step in `cloudbuild.yaml`
2. Use Cloud Build approval API
3. Or use Cloud Deploy for advanced approval workflows

## Security Best Practices

1. **Use Secret Manager** - Never hardcode credentials
2. **Least Privilege** - Grant only necessary IAM roles
3. **Audit Logs** - Regularly review Cloud Build and Cloud Run logs
4. **Branch Protection** - Use GitHub branch protection rules
5. **Image Scanning** - Enable Container Analysis API for vulnerability scanning

## Cost Optimization

- **Build Timeouts** - Set appropriate timeouts to avoid long-running builds
- **Machine Type** - Use appropriate machine types (default: E2_HIGHCPU_8)
- **Caching** - Use Docker layer caching in builds
- **Scale to Zero** - Cloud Run scales to zero when not in use

## Quick Reference

| Task | Command |
|------|---------|
| Setup secrets | `./setup-gcp-secrets.sh` |
| Setup Cloud Build SA | `./setup-cloud-build-sa.sh` |
| Create trigger | `./setup-cicd-trigger.sh owner repo project branch` |
| Grant secret access | `./grant-secret-access.sh service region` |
| Test build | `./test-cloudbuild.sh` |
| View builds | `gcloud builds list` |
| View logs | `gcloud builds log [BUILD_ID]` |

## Next Steps

- Set up monitoring and alerting
- Configure custom domains
- Set up staging environment
- Enable build notifications
- Configure branch protection in GitHub

