"""
Interactive chat demo with Vertex AI RAG.
Uses Application Default Credentials (gcloud auth application-default login).
"""
import os
import sys
from google import genai
from google.genai import types


def interactive_chat() -> None:
    """Run an interactive chat session with RAG-enabled model."""
    project_id = os.getenv("PROJECT_ID", "appier-airis-tstc")
    location = os.getenv("LOCATION", "asia-east1")
    model_name = os.getenv("MODEL_NAME", "gemini-2.5-flash")
    rag_corpus_name = os.getenv(
        "RAG_CORPUS_NAME",
        "projects/appier-airis-tstc/locations/asia-east1/ragCorpora/4611686018427387904",
    ).strip()

    if not rag_corpus_name:
        print("❌ RAG_CORPUS_NAME is not set.")
        print("Set it to a resource like:")
        print(f"  projects/{project_id}/locations/{location}/ragCorpora/###########")
        sys.exit(1)

    # Initialize client with ADC (no API key needed)
    print("🔐 Authenticating with Application Default Credentials...")
    try:
        client = genai.Client(
            vertexai=True,
            project=project_id,
            location=location,
        )
        print(f"✅ Connected to project: {project_id}, location: {location}")
    except Exception as e:
        print(f"❌ Authentication failed: {e}")
        print("\nPlease run:")
        print("  gcloud auth login")
        print("  gcloud auth application-default login")
        sys.exit(1)

    # Setup RAG tool
    tools = [
        types.Tool(
            retrieval=types.Retrieval(
                vertex_rag_store=types.VertexRagStore(
                    rag_resources=[
                        types.VertexRagStoreRagResource(rag_corpus=rag_corpus_name)
                    ],
                )
            )
        )
    ]

    config = types.GenerateContentConfig(
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

    # Conversation history
    conversation_history = []

    print(f"\n🤖 Model: {model_name}")
    print(f"📚 RAG Corpus: {rag_corpus_name}")
    print("\n" + "=" * 80)
    print("💬 Interactive Chat Session Started")
    print("=" * 80)
    print("💡 Type your questions. The model will use your RAG corpus to answer.")
    print("💡 Commands:")
    print("   - Type 'exit' or 'quit' to end the session")
    print("   - Type 'clear' to clear conversation history")
    print("   - Type 'history' to see conversation history")
    print("=" * 80 + "\n")

    while True:
        try:
            # Get user input
            user_input = input("You: ").strip()

            if not user_input:
                continue

            # Handle commands
            if user_input.lower() in ["exit", "quit", "q"]:
                print("\n👋 Goodbye!")
                break

            if user_input.lower() == "clear":
                conversation_history = []
                print("🧹 Conversation history cleared.\n")
                continue

            if user_input.lower() == "history":
                if not conversation_history:
                    print("📜 No conversation history yet.\n")
                else:
                    print("\n📜 Conversation History:")
                    print("-" * 80)
                    for i, (role, text) in enumerate(conversation_history, 1):
                        role_icon = "👤" if role == "user" else "🤖"
                        print(f"{i}. {role_icon} {role.capitalize()}: {text[:100]}...")
                    print("-" * 80 + "\n")
                continue

            # Add user message to history
            conversation_history.append(("user", user_input))

            # Build conversation context
            contents = []
            for role, text in conversation_history:
                contents.append(
                    types.Content(
                        role=role,
                        parts=[types.Part.from_text(text=text)],
                    )
                )

            # Generate response
            print("\n🤖 Assistant: ", end="", flush=True)
            response_text = ""

            try:
                for chunk in client.models.generate_content_stream(
                    model=model_name, contents=contents, config=config
                ):
                    if not chunk.candidates or not chunk.candidates[0].content:
                        continue
                    if chunk.text:
                        print(chunk.text, end="", flush=True)
                        response_text += chunk.text

                print("\n")  # New line after response

                # Add assistant response to history
                if response_text:
                    conversation_history.append(("model", response_text))

            except Exception as e:
                error_msg = f"Error generating response: {e}"
                print(f"\n❌ {error_msg}")
                # Remove the user message from history if generation failed
                if conversation_history and conversation_history[-1][0] == "user":
                    conversation_history.pop()

        except KeyboardInterrupt:
            print("\n\n👋 Interrupted. Goodbye!")
            break
        except EOFError:
            print("\n\n👋 Goodbye!")
            break
        except Exception as e:
            print(f"\n❌ Unexpected error: {e}")
            print("Continuing...\n")


if __name__ == "__main__":
    interactive_chat()

