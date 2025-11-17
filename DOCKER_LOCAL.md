# Running Docker Locally

This guide helps you test the Slack bot in a Docker container locally before deploying to Cloud Run.

## Prerequisites

- Docker installed and running
- Environment variables set (see below)

## Quick Start

### Option 1: Interactive Mode (See logs in real-time)

```bash
# Set your environment variables
export SLACK_BOT_TOKEN="xoxb-..."
export SLACK_SIGNING_SECRET="..."
export PROJECT_ID="appier-airis-tstc"
export LOCATION="us-central1"
export MODEL_NAME="gemini-2.5-flash"
export RAG_CORPUS_NAME="projects/appier-airis-tstc/locations/asia-east1/ragCorpora/4611686018427387904"

# Run interactively (logs will show in terminal)
./docker-test.sh
```

Press `Ctrl+C` to stop the container.

### Option 2: Detached Mode (Background)

```bash
# Set your environment variables (same as above)
export SLACK_BOT_TOKEN="xoxb-..."
export SLACK_SIGNING_SECRET="..."
export PROJECT_ID="appier-airis-tstc"
export LOCATION="us-central1"
export MODEL_NAME="gemini-2.5-flash"
export RAG_CORPUS_NAME="projects/appier-airis-tstc/locations/asia-east1/ragCorpora/4611686018427387904"

# Run in background
./docker-run-local.sh
```

View logs:
```bash
docker logs -f tstc-slack-bot-container
```

Stop the container:
```bash
docker stop tstc-slack-bot-container
```

## Manual Docker Commands

If you prefer to run Docker commands manually:

### 1. Build the Image

```bash
docker build -t tstc-slack-bot-local:latest .
```

### 2. Run the Container

```bash
docker run -d \
  --name tstc-slack-bot-container \
  -p 3000:8080 \
  -e PORT=8080 \
  -e SLACK_BOT_TOKEN="xoxb-..." \
  -e SLACK_SIGNING_SECRET="..." \
  -e PROJECT_ID="appier-airis-tstc" \
  -e LOCATION="us-central1" \
  -e MODEL_NAME="gemini-2.5-flash" \
  -e RAG_CORPUS_NAME="projects/appier-airis-tstc/locations/asia-east1/ragCorpora/4611686018427387904" \
  tstc-slack-bot-local:latest
```

### 3. Check Status

```bash
# List running containers
docker ps

# View logs
docker logs -f tstc-slack-bot-container

# Check if service is responding
curl http://localhost:3000/health
```

### 4. Stop and Remove

```bash
docker stop tstc-slack-bot-container
docker rm tstc-slack-bot-container
```

## Testing with ngrok

To test with Slack webhooks locally:

1. **Start the Docker container** (using one of the methods above)

2. **Start ngrok** in another terminal:
   ```bash
   ngrok http 3000
   ```

3. **Update Slack App**:
   - Go to Slack API Dashboard → Your App → Event Subscriptions
   - Set Request URL to: `https://YOUR-NGROK-URL.ngrok.io/slack/events`

4. **Test**:
   - Mention your bot in Slack
   - Check Docker logs: `docker logs -f tstc-slack-bot-container`

## Troubleshooting

### Container won't start

Check logs:
```bash
docker logs tstc-slack-bot-container
```

Common issues:
- Missing environment variables
- Port 3000 already in use (change PORT in the script)
- Docker daemon not running

### Authentication errors

The container uses Application Default Credentials. For local Docker, you may need to:

1. **Mount gcloud credentials** (not recommended for production):
   ```bash
   docker run ... \
     -v ~/.config/gcloud:/root/.config/gcloud:ro \
     ...
   ```

2. **Or use a service account key**:
   ```bash
   # Create service account key
   gcloud iam service-accounts keys create key.json \
     --iam-account=YOUR_SERVICE_ACCOUNT@PROJECT.iam.gserviceaccount.com
   
   # Mount it in Docker
   docker run ... \
     -v $(pwd)/key.json:/app/key.json:ro \
     -e GOOGLE_APPLICATION_CREDENTIALS=/app/key.json \
     ...
   ```

### Port conflicts

If port 3000 is in use, change it:
```bash
PORT=8080 ./docker-run-local.sh
```

Or manually:
```bash
docker run -p 8080:8080 ...
```

### View container shell

To debug inside the container:
```bash
docker exec -it tstc-slack-bot-container /bin/bash
```

### Rebuild after code changes

```bash
# Stop and remove old container
docker stop tstc-slack-bot-container
docker rm tstc-slack-bot-container

# Rebuild image
docker build -t tstc-slack-bot-local:latest .

# Run again
./docker-run-local.sh
```

## Environment Variables

Required:
- `SLACK_BOT_TOKEN` - Your Slack bot token
- `SLACK_SIGNING_SECRET` - Your Slack signing secret

Optional (with defaults):
- `PROJECT_ID` - Default: `appier-airis-tstc`
- `LOCATION` - Default: `us-central1`
- `MODEL_NAME` - Default: `gemini-2.5-flash`
- `RAG_CORPUS_NAME` - Your RAG corpus resource name
- `PORT` - Default: `8080` (inside container)

## Next Steps

Once local Docker testing works:
1. Test with Slack webhooks using ngrok
2. Verify RAG responses work correctly
3. Deploy to Cloud Run using `deploy.sh` or `DEPLOY.md`

