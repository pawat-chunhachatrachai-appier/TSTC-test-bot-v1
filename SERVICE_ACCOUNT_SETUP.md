# Running Scripts with Service Account

Yes, these scripts will work with a service account, but the service account needs proper IAM roles and authentication. Here's how to set it up:

## 🔐 Required IAM Roles

The service account needs these roles to run all 3 scripts:

### For `setup-gcp-secrets.sh`:
- `roles/secretmanager.admin` - Create and manage secrets
- `roles/serviceusage.serviceUsageAdmin` - Enable APIs (or `roles/owner`)

### For `grant-secret-access.sh`:
- `roles/secretmanager.admin` - Grant IAM permissions on secrets
- `roles/run.viewer` - View Cloud Run services (or `roles/run.admin`)

### For `deploy.sh`:
- `roles/run.admin` - Deploy to Cloud Run
- `roles/storage.admin` - Push to Container Registry (or `roles/storage.objectAdmin`)
- `roles/secretmanager.viewer` - Check if secrets exist (or `roles/secretmanager.secretAccessor`)

### Recommended: Use a Custom Role or Grant These Roles

**Option 1: Grant all required roles (easiest)**
```bash
SERVICE_ACCOUNT_EMAIL="your-service-account@project-id.iam.gserviceaccount.com"
PROJECT_ID="appier-airis-tstc"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/secretmanager.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/serviceusage.serviceUsageAdmin"
```

**Option 2: Use a custom role (more secure, least privilege)**
See `create-custom-role.sh` script below.

## 🔑 Authenticating as Service Account

### Method 1: Using Service Account Key File

1. **Create and download a service account key:**
   ```bash
   # Create service account (if not exists)
   gcloud iam service-accounts create deployer \
     --display-name="Deployment Service Account" \
     --project=appier-airis-tstc
   
   # Grant roles (see above)
   
   # Create and download key
   gcloud iam service-accounts keys create deployer-key.json \
     --iam-account=deployer@appier-airis-tstc.iam.gserviceaccount.com \
     --project=appier-airis-tstc
   ```

2. **Authenticate with the key:**
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="./deployer-key.json"
   gcloud auth activate-service-account --key-file=./deployer-key.json
   ```

3. **Set the project:**
   ```bash
   gcloud config set project appier-airis-tstc
   ```

4. **Run the scripts:**
   ```bash
   ./setup-gcp-secrets.sh
   ./deploy.sh
   ./grant-secret-access.sh
   ```

### Method 2: Using Application Default Credentials (ADC)

If running on GCP (Cloud Build, Compute Engine, etc.), ADC is automatically available:

```bash
# No authentication needed - uses the service account attached to the resource
./setup-gcp-secrets.sh
./deploy.sh
./grant-secret-access.sh
```

### Method 3: Impersonating a Service Account

If you have permission to impersonate:

```bash
gcloud config set auth/impersonate_service_account deployer@appier-airis-tstc.iam.gserviceaccount.com

# Now run scripts normally
./setup-gcp-secrets.sh
./deploy.sh
./grant-secret-access.sh
```

## 📋 Quick Setup Script

Create a service account with all required permissions:

```bash
#!/bin/bash
# create-deployer-sa.sh

PROJECT_ID="${PROJECT_ID:-appier-airis-tstc}"
SA_NAME="deployer"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Creating service account: ${SA_NAME}..."

# Create service account
gcloud iam service-accounts create ${SA_NAME} \
  --display-name="Deployment Service Account" \
  --project=${PROJECT_ID} 2>/dev/null || echo "Service account already exists"

# Grant required roles
echo "Granting IAM roles..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/secretmanager.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/serviceusage.serviceUsageAdmin"

echo "✅ Service account created: ${SA_EMAIL}"
echo ""
echo "To create and download a key:"
echo "  gcloud iam service-accounts keys create deployer-key.json \\"
echo "    --iam-account=${SA_EMAIL} \\"
echo "    --project=${PROJECT_ID}"
echo ""
echo "To authenticate:"
echo "  export GOOGLE_APPLICATION_CREDENTIALS=\"./deployer-key.json\""
echo "  gcloud auth activate-service-account --key-file=./deployer-key.json"
```

## ⚠️ Security Best Practices

1. **Store key file securely** - Never commit `deployer-key.json` to git
2. **Use least privilege** - Only grant necessary roles
3. **Rotate keys regularly** - Delete old keys and create new ones
4. **Use Workload Identity** - For GKE/Cloud Build, use Workload Identity instead of keys
5. **Monitor usage** - Review audit logs regularly

## 🔍 Verify Service Account Permissions

```bash
# Check what roles the service account has
gcloud projects get-iam-policy ${PROJECT_ID} \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

## 🚨 Troubleshooting

### "Permission denied" errors
- Verify service account has required roles (see above)
- Check you're authenticated with the correct account: `gcloud auth list`

### "Service account key not found"
- Make sure `GOOGLE_APPLICATION_CREDENTIALS` points to the key file
- Verify the key file exists and is readable

### "API not enabled"
- The service account needs `roles/serviceusage.serviceUsageAdmin` to enable APIs
- Or enable APIs manually: `gcloud services enable secretmanager.googleapis.com`

