import os
from typing import Dict, List, Tuple

from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
from slack_bolt import App as SlackApp
from slack_bolt.adapter.flask import SlackRequestHandler
from slack_sdk.errors import SlackApiError

try:
    from google import genai
    from google.genai import types
except Exception:
    genai = None
    types = None


load_dotenv()

required_env = ["SLACK_SIGNING_SECRET", "SLACK_BOT_TOKEN"]
missing = [k for k in required_env if not os.environ.get(k)]
if missing:
  raise SystemExit(f"Missing required environment variables: {', '.join(missing)}")

PORT = int(os.environ.get("PORT", "3000"))

# Vertex AI RAG configuration
PROJECT_ID = os.getenv("PROJECT_ID", "appier-airis-tstc")
LOCATION = os.getenv("LOCATION", "asia-east1")
MODEL_NAME = os.getenv("MODEL_NAME", "gemini-2.5-flash")
RAG_CORPUS_NAME = os.getenv(
    "RAG_CORPUS_NAME",
    "projects/appier-airis-tstc/locations/asia-east1/ragCorpora/4611686018427387904",
).strip()

# Slack Bolt app
slack_app = SlackApp(
  token=os.getenv("SLACK_BOT_TOKEN", ""),
  signing_secret=os.getenv("SLACK_SIGNING_SECRET", "")
)

# Store conversation history per thread (key: thread_ts, value: list of (role, text) tuples)
conversation_history: Dict[str, List[Tuple[str, str]]] = {}


def _init_rag_client():
    """Initialize Vertex AI RAG client using Application Default Credentials."""
    if genai is None or types is None:
        return None
    if not RAG_CORPUS_NAME:
        return None
    try:
        client = genai.Client(
            vertexai=True,
            project=PROJECT_ID,
            location=LOCATION,
        )
        return client
    except Exception as e:
        print(f"Failed to initialize RAG client: {e}")
        return None


_rag_client = _init_rag_client()


def _get_rag_config():
    """Get RAG configuration with retrieval tool."""
    if not RAG_CORPUS_NAME or types is None:
        return None
    
    tools = [
        types.Tool(
            retrieval=types.Retrieval(
                vertex_rag_store=types.VertexRagStore(
                    rag_resources=[
                        types.VertexRagStoreRagResource(rag_corpus=RAG_CORPUS_NAME)
                    ],
                )
            )
        )
    ]
    
    return types.GenerateContentConfig(
        temperature=1.0,
        top_p=0.95,
        max_output_tokens=8192,
        safety_settings=[
            types.SafetySetting(category="HARM_CATEGORY_HATE_SPEECH", threshold="OFF"),
            types.SafetySetting(
                category="HARM_CATEGORY_DANGEROUS_CONTENT", threshold="OFF"
            ),
            types.SafetySetting(
                category="HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold="OFF"
            ),
            types.SafetySetting(category="HARM_CATEGORY_HARASSMENT", threshold="OFF"),
        ],
        tools=tools,
    )


_rag_config = _get_rag_config()


def _strip_bot_mention(text: str) -> str:
    """Remove bot mention from text."""
    if not text:
        return ""
    # Remove <@UXXXX> mentions
    return " ".join(part for part in text.split() if not part.startswith("<@") and not part.endswith(">")) or text


def generate_reply_with_rag(user_text: str, thread_ts: str) -> str:
    """Generate reply using Vertex AI RAG with conversation history."""
    if not user_text:
        return ""
    
    # Fallback if RAG client isn't available
    if _rag_client is None or _rag_config is None:
        return "⚠️ RAG engine not configured. Please check your Vertex AI setup."
    
    try:
        # Get or initialize conversation history for this thread
        if thread_ts not in conversation_history:
            conversation_history[thread_ts] = []
        
        # Add user message to history
        conversation_history[thread_ts].append(("user", user_text))
        
        # Build conversation context from history
        contents = []
        for role, text in conversation_history[thread_ts]:
            contents.append(
                types.Content(
                    role=role,
                    parts=[types.Part.from_text(text=text)],
                )
            )
        
        # Generate response with streaming
        response_text = ""
        for chunk in _rag_client.models.generate_content_stream(
            model=MODEL_NAME, contents=contents, config=_rag_config
        ):
            if not chunk.candidates or not chunk.candidates[0].content:
                continue
            if chunk.text:
                response_text += chunk.text
        
        # Add assistant response to history
        if response_text:
            conversation_history[thread_ts].append(("model", response_text))
            return response_text
        
        return "⚠️ No response generated."
    
    except Exception as e:
        error_msg = str(e)
        print(f"Error generating reply: {error_msg}")
        # Remove the user message from history if generation failed
        if thread_ts in conversation_history and conversation_history[thread_ts] and conversation_history[thread_ts][-1][0] == "user":
            conversation_history[thread_ts].pop()
        return f"⚠️ Sorry, I encountered an error. Please try again."


@slack_app.event("app_mention")
def handle_app_mention(body, say):
    """Handle app mentions with Gemini RAG."""
    event = body.get("event", {}) or {}
    channel = event.get("channel")
    thread_ts = event.get("thread_ts") or event.get("ts")
    text = event.get("text", "")
    
    # Strip bot mention and get user's message
    user_message = _strip_bot_mention(text)
    
    if not user_message:
        say(text="👋 Hi! How can I help you?", thread_ts=thread_ts)
        return
    
    # Generate reply using Gemini RAG
    reply = generate_reply_with_rag(user_message, thread_ts)
    
    if reply:
        say(text=reply, thread_ts=thread_ts)
    else:
        say(text="⚠️ Could not generate a response.", thread_ts=thread_ts)


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


