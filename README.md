# TSTC Slack Bot (Python)

Minimal Flask + Slack Bolt app that replies with a random message when mentioned, and exposes simple backend APIs.

## Prerequisites

- Python 3.9+
- A Slack workspace where you can install a custom app

## Setup

1. Create a Slack app:
   - Go to Slack API dashboard and create an app from scratch.
   - Add the following Bot Token Scopes under OAuth & Permissions:
     - `app_mentions:read`
     - `chat:write`
   - Install the app to your workspace. Copy the Bot User OAuth Token (starts with `xoxb-`).
   - Copy the Signing Secret from Basic Information.

2. Configure Events:
   - Under Event Subscriptions, enable events.
   - Set the Request URL to `https://YOUR_HOST/slack/events` (use a tunnel like ngrok when running locally).
   - Subscribe to bot events: `app_mention`.

3. Configure environment:
   - Copy `env.example` to `.env` and fill in values.

4. Install dependencies:
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # Windows: .venv\\Scripts\\activate
   pip install -r requirements.txt
   ```

5. Run locally:
   ```bash
   python src/app.py
   ```

6. Expose to Slack (local dev):
   - Start a tunnel, e.g. with ngrok: `ngrok http 3000`
   - Use the given public URL for the Slack Request URL `/slack/events`.

## Usage

- Mention the bot in any channel it is a member of. It will respond with a random message.
- Health check: `GET /health`
- Ping: `GET /api/ping`
- Notify: `POST /api/notify` with JSON `{ "channel": "#general", "text": "Hello" }`

## Notes

- You can also set `SLACK_DEFAULT_CHANNEL` in `.env` so `/api/notify` works without providing `channel`.


