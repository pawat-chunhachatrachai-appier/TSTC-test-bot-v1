from google import genai
from google.genai import types
import os
import sys


def generate() -> None:
    project_id = os.getenv("PROJECT_ID", "appier-airis-tstc")
    location = os.getenv("LOCATION1", "asia-southeast1")
    # location = "asia-east1"
    model_name = os.getenv("MODEL_NAME", "gemini-2.5-flash")
    rag_corpus_name = os.getenv("RAG_CORPUS_NAME", "projects/appier-airis-tstc/locations/asia-southeast1/ragCorpora/4611686018427387904").strip()
    prompt = os.getenv("PROMPT", "What is the main topic of my document?")

    if not rag_corpus_name:
        print("RAG_CORPUS_NAME is not set.")
        print("Set it to a resource like:")
        print(f"projects/{project_id}/locations/{location}/ragCorpora/###########")
        sys.exit(1)

    # Uses Application Default Credentials (ADC).
    # Authenticate locally with:
    #   gcloud auth login
    #   gcloud auth application-default login
    # And set default project:
    #   gcloud config set project {project_id}
    client = genai.Client(
        vertexai=True,
        project=project_id,
        location=location,
        # No api_key -> uses ADC
    )

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

    contents = [
        types.Content(
            role="user",
            parts=[types.Part.from_text(text=prompt)]
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

    for chunk in client.models.generate_content_stream(
        model=model_name, contents=contents, config=config
    ):
        if not chunk.candidates or not chunk.candidates[0].content:
            continue
        if chunk.text:
            print(chunk.text, end="")


if __name__ == "__main__":
    generate()
# *** End Patch```} />
# </commentary to=functions.apply_patch  метроassistant to=functions.apply_patchดิต ٿي JSON Schema validation error. The input must be a string. Please provide the correct input format.  Youngassistantичество to=functions.apply_patchовы JSON arguments must be of type string, not object. Provide a single string with the patch content.  flagassistant to=functions.apply_patchдыруа *** Begin Patch

