# Setting Up Credentials for TSTC Slack Bot

This guide explains how to securely manage credentials for both local development and GCP deployment.

## 🔐 Security Best Practices

- **NEVER commit `.env` file to git** (it's already in `.gitignore`)
- **Use `.env` for local development only**
- **Use GCP Secret Manager for production deployments**

## 📝 Step 1: Create Local .env File

1. Copy the example file:
   ```bash
   cp env.example .env
   ```

2. Edit `.env` and fill in your credentials:
   ```bash
   # Required
   SLACK_BOT_TOKEN=xoxb-your-token-here
   SLACK_SIGNING_SECRET=your-signing-secret-here
   
   # Optional
   SLACK_DEFAULT_CHANNEL=#general
   
   # GCP Configuration (used by deploy script)
   PROJECT_ID=appier-airis-tstc
   LOCATION=us-central1
   MODEL_NAME=gemini-2.5-flash
   RAG_CORPUS_NAME=projects/appier-airis-tstc/locations/asia-east1/ragCorpora/4611686018427387904
   ```

3. Verify `.env` is in `.gitignore` (it should be):
   ```bash
   grep -q "^\.env$" .gitignore && echo "✅ .env is ignored" || echo "❌ .env not in .gitignore"
   ```

## 🚀 Step 2: Sync Credentials to GCP Secret Manager

After creating your `.env` file, sync it to GCP Secret Manager:

```bash
./setup-gcp-secrets.sh
```

This script will:
- ✅ Read credentials from your `.env` file
- ✅ Create/update secrets in GCP Secret Manager
- ✅ Store: `slack-bot-token`, `slack-signing-secret`, and optionally `slack-default-channel`

## 🔑 Step 3: Grant Secret Access to Cloud Run

Before deploying, grant your Cloud Run service access to the secrets:

```bash
./grant-secret-access.sh [service-name] [region]
```

Or after deployment:
```bash
./grant-secret-access.sh tstc-slack-bot us-central1
```

## 📦 Step 4: Deploy to GCP

Deploy your service (the script will automatically use Secret Manager):

```bash
./deploy.sh [service-name] [region]
```

Example:
```bash
./deploy.sh tstc-slack-bot us-central1
```

## 🔍 Verify Secrets

Check if secrets exist:
```bash
gcloud secrets list --project=appier-airis-tstc
```

View secret metadata (not the value):
```bash
gcloud secrets describe slack-bot-token --project=appier-airis-tstc
```

## 🔄 Update Secrets

To update a secret in GCP:

1. Update your local `.env` file
2. Run the sync script again:
   ```bash
   ./setup-gcp-secrets.sh
   ```
3. The script will create a new version of the secret
4. Cloud Run will automatically use the latest version (if you used `:latest`)

## 📋 Quick Reference

| Task | Command |
|------|---------|
| Create .env | `cp env.example .env` |
| Sync to GCP | `./setup-gcp-secrets.sh` |
| Grant access | `./grant-secret-access.sh` |
| Deploy | `./deploy.sh` |
| Check secrets | `gcloud secrets list` |
| View logs | `gcloud run services logs read tstc-slack-bot --region us-central1` |

## ⚠️ Troubleshooting

### "Secret not found" error
- Make sure you ran `./setup-gcp-secrets.sh` first
- Verify the secret name matches: `slack-bot-token`, `slack-signing-secret`

### "Permission denied" error
- Run `./grant-secret-access.sh` to grant Cloud Run access
- Check your service account has `roles/secretmanager.secretAccessor`

### Local development not working
- Make sure `.env` file exists and has correct values
- Check `docker-run-local.sh` loads `.env` correctly
- Verify Docker is running: `docker ps`

## 🔒 Security Notes

1. **Never commit `.env`** - It's in `.gitignore` but double-check before committing
2. **Rotate secrets regularly** - Update secrets in Secret Manager periodically
3. **Use least privilege** - Only grant secret access to services that need it
4. **Monitor access** - Review Secret Manager audit logs regularly

