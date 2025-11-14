# TSTC Slack Bot with Vertex AI RAG

A Slack bot powered by Google Vertex AI RAG (Retrieval-Augmented Generation) that answers questions using your knowledge base. The bot maintains conversation context per thread and uses Application Default Credentials (gcloud auth) - no API keys required.

## Features

- 🤖 **Slack Bot Integration**: Responds to mentions and DMs in Slack
- 📚 **RAG-Powered**: Uses Vertex AI RAG to answer questions from your knowledge corpus
- 💬 **Conversation History**: Maintains context per Slack thread
- 🔐 **Secure Auth**: Uses gcloud Application Default Credentials (no API keys)
- 🛠️ **Utility Scripts**: Tools to list models, corpora, and test RAG interactions

## Project Structure

```
.
├── slack/
│   └── src/
│       └── app.py              # Main Slack bot with RAG integration
├── interactive_chat.py          # Interactive CLI chat with RAG
├── preview.py                   # Simple RAG preview script
├── list_models.py               # List available Gemini models by region
├── list_rag_corpara.py          # List RAG corpora in a region
├── test.py                      # Test RAG corpus creation and queries
└── requirements.txt             # Python dependencies
```

## Prerequisites

- Python 3.10+
- Google Cloud SDK (`gcloud`) installed and authenticated
- A Slack workspace where you can install a custom app
- Vertex AI RAG corpus created in Google Cloud

## Setup

### 1. Google Cloud Authentication

```bash
# Authenticate with Google Cloud (one-time setup)
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### 2. Install Dependencies

```bash
# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 3. Configure Environment Variables

Create a `.env` file or export environment variables:

```bash
# Slack credentials
export SLACK_BOT_TOKEN="xoxb-..."
export SLACK_SIGNING_SECRET="..."

# Vertex AI RAG configuration
export PROJECT_ID="appier-airis-tstc"
export LOCATION="us-central1"  # Use a region with Gemini models (not asia-east1)
export MODEL_NAME="gemini-2.5-flash"  # or gemini-2.0-flash-001
export RAG_CORPUS_NAME="projects/YOUR_PROJECT/locations/YOUR_REGION/ragCorpora/YOUR_CORPUS_ID"

# Optional
export PORT="3000"
```

**Important Notes:**
- `LOCATION` should be a region that has Gemini models (e.g., `us-central1`, `europe-west1`)
- `asia-east1` only has Imagen models, not Gemini
- Your RAG corpus can be in a different region than the model

### 4. Find Your RAG Corpus

If you don't know your RAG corpus name:

```bash
export LOCATION="asia-east1"  # or your corpus region
python list_rag_corpara.py
```

### 5. Check Available Models

To see which Gemini models are available in a region:

```bash
export LOCATION="us-central1"
python list_models.py
```

### 6. Slack App Configuration

1. **Create a Slack App:**
   - Go to [Slack API Dashboard](https://api.slack.com/apps)
   - Create an app from scratch
   - Add Bot Token Scopes:
     - `app_mentions:read`
     - `chat:write`
     - `im:history`
   - Install the app to your workspace
   - Copy the Bot User OAuth Token (starts with `xoxb-`)
   - Copy the Signing Secret from Basic Information

2. **Configure Events:**
   - Under Event Subscriptions, enable events
   - Set Request URL to `https://YOUR_HOST/slack/events`
   - Subscribe to bot events: `app_mention`, `message.im`

3. **For Local Development:**
   - Use ngrok or cloudflared to expose your local server
   - Example: `ngrok http 3000`
   - Use the public URL for the Slack Request URL

## Usage

### Run the Slack Bot

```bash
cd slack/src
source ../../.venv/bin/activate  # if not already activated
export SLACK_BOT_TOKEN="xoxb-..."
export SLACK_SIGNING_SECRET="..."
export LOCATION="us-central1"
export MODEL_NAME="gemini-2.5-flash"
export RAG_CORPUS_NAME="projects/..."

python app.py
```

The bot will:
- Respond to `@bot` mentions in channels
- Respond to direct messages
- Maintain conversation history per thread
- Use your RAG corpus to provide context-aware answers

### Interactive Chat (CLI)

Test the RAG system interactively:

```bash
export LOCATION="us-central1"
export MODEL_NAME="gemini-2.5-flash"
export RAG_CORPUS_NAME="projects/..."
python interactive_chat.py
```

Commands:
- Type questions to chat with the bot
- `exit` or `quit` to end session
- `clear` to clear conversation history
- `history` to view conversation history

### Preview RAG Response

Quick test of RAG with a single question:

```bash
export PROMPT="What is the main topic of my document?"
python preview.py
```

### List Available Models

Check which models are available in a region:

```bash
export LOCATION="us-central1"
python list_models.py
```

### List RAG Corpora

List all RAG corpora in a region:

```bash
export LOCATION="asia-east1"
python list_rag_corpara.py
```

## API Endpoints

The Slack bot also exposes REST endpoints:

- `GET /health` - Health check
- `GET /api/ping` - Ping endpoint with timestamp
- `POST /api/notify` - Send a message to a Slack channel
  ```json
  {
    "channel": "#general",
    "text": "Hello from API!"
  }
  ```

## Troubleshooting

### Model Not Found Error

If you see `404 NOT_FOUND` for a model:
- Check that `LOCATION` is set to a region with Gemini models
- Run `python list_models.py` to see available models
- Common regions with Gemini: `us-central1`, `europe-west1`, `europe-west4`

### RAG Engine Not Configured

- Verify `RAG_CORPUS_NAME` is set correctly
- Check that you've run `gcloud auth application-default login`
- Ensure your account has `roles/aiplatform.user` permission

### Authentication Errors

```bash
# Re-authenticate
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### Region Compatibility

- Your RAG corpus can be in one region (e.g., `asia-east1`)
- The model can be in another region (e.g., `us-central1`)
- Vertex AI RAG supports cross-region access

## Development

### Project Structure

- `slack/src/app.py` - Main Slack bot with RAG integration
- `interactive_chat.py` - Interactive CLI for testing RAG
- `preview.py` - Simple RAG preview script
- `list_models.py` - Utility to list available models
- `list_rag_corpara.py` - Utility to list RAG corpora
- `test.py` - Test script for RAG corpus operations

### Dependencies

See `requirements.txt` for full list. Key dependencies:
- `google-cloud-aiplatform` - Vertex AI SDK
- `slack-bolt` - Slack Bolt framework
- `flask` - Web framework
- `python-dotenv` - Environment variable management

## Notes

- The bot maintains separate conversation history for each Slack thread
- Responses are generated using streaming for better UX
- All authentication uses Application Default Credentials (no API keys)
- Make sure Vertex AI API is enabled in your GCP project

## License

[Add your license here]

## Support

For issues or questions, please open an issue in the repository.
