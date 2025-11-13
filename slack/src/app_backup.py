import os
import random

from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
from slack_bolt import App as SlackApp
from slack_bolt.adapter.flask import SlackRequestHandler
from slack_sdk.errors import SlackApiError


load_dotenv()

required_env = ["SLACK_SIGNING_SECRET", "SLACK_BOT_TOKEN"]
missing = [k for k in required_env if not os.environ.get(k)]
if missing:
  raise SystemExit(f"Missing required environment variables: {', '.join(missing)}")

PORT = int(os.environ.get("PORT", "3000"))

# Slack Bolt app
slack_app = SlackApp(
  token=os.environ["SLACK_BOT_TOKEN"],
  signing_secret=os.environ["SLACK_SIGNING_SECRET"],
)

# Random replies for mentions
RANDOM_REPLIES = [
  "Hi there! 👋",
  "How can I help you today?",
  "Here and listening. 😄",
  "At your service! 🤖",
  "What's up?",
  "I'm here to help! 🤖",
]


@slack_app.event("app_mention")
def handle_app_mention(body, say):
  event = body.get("event", {}) or {}
  channel = event.get("channel")
  thread_ts = event.get("thread_ts") or event.get("ts")
  current_ts = event.get("ts")
  try:
    replies = slack_app.client.conversations_replies(channel=channel, ts=thread_ts, inclusive=True)
    messages = replies.get("messages", [])
    texts = []
    for m in messages:
      ts = m.get("ts")
      text = m.get("text")
      if not text or not ts:
        continue
      # Only include messages posted before the current mention
      try:
        if float(ts) >= float(current_ts):
          continue
      except Exception:
        pass
      texts.append(text)
    content = "\n".join(texts) if texts else "(no prior messages)"
    say(text=content, thread_ts=thread_ts)
  except SlackApiError as e:
    try:
      status = getattr(e.response, "status_code", None)
      data = getattr(e.response, "data", None)
      print("conversations_replies error:", status, data)
      err = (data or {}).get("error") if isinstance(data, dict) else None
    except Exception:
      print("conversations_replies error (no response):", repr(e))
    if err:
      say(text=f"Couldn't read the thread: {err}", thread_ts=thread_ts)
    else:
      say(text="Couldn't read the thread (auth/scopes?).", thread_ts=thread_ts)
  except Exception as e:
    print("unexpected error in app_mention handler:", repr(e))
    say(text="Couldn't read the thread.", thread_ts=thread_ts)


# Flask app
flask_app = Flask(__name__)
CORS(flask_app)
handler = SlackRequestHandler(slack_app)


@flask_app.get("/health")
def health():
  return "ok", 200


@flask_app.get("/api/ping")
def ping():
  return jsonify({"ok": True, "ts": int(__import__("time").time() * 1000)})


@flask_app.post("/api/notify")
def notify():
  data = request.get_json(silent=True) or {}
  channel = data.get("channel") or os.environ.get("SLACK_DEFAULT_CHANNEL")
  text = data.get("text") or "Hello from Python backend!"
  if not channel:
    return jsonify({"ok": False, "error": "channel is required (or SLACK_DEFAULT_CHANNEL)"}), 400
  try:
    result = slack_app.client.chat_postMessage(channel=channel, text=text)
    return jsonify({"ok": True, "channel": channel, "ts": result.get("ts")})
  except Exception as e:
    return jsonify({"ok": False, "error": str(e)}), 500


@flask_app.post("/slack/events")
def slack_events():
  return handler.handle(request)


if __name__ == "__main__":
  flask_app.run(host="0.0.0.0", port=PORT)


