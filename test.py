import vertexai
import os
import sys
from vertexai.preview import rag
from vertexai.preview.generative_models import GenerativeModel, Tool

# --- 1. Initialize Vertex AI ---
# Your ADC (from gcloud auth application-default login) will be used
# automatically.
PROJECT_ID = "appier-airis-tstc"  # 👈 Updated to your active gcloud project
# Allow overriding region via env var to list/use corpora in other regions
LOCATION = os.getenv("LOCATION", "asia-east1")
MODEL_NAME = os.getenv("MODEL_NAME", "gemini-1.5-pro-002")
GCS_FILE_PATH = "gs://your-bucket-name/my-document.pdf" # 👈 Update this

vertexai.init(project=PROJECT_ID, location=LOCATION)

# --- 2. Use an existing RAG Corpus or list available ones ---
rag_corpus_name = os.getenv("RAG_CORPUS_NAME", "").strip()

if not rag_corpus_name:
    print(f"[Project: {PROJECT_ID} | Region: {LOCATION}] Listing existing RAG corpora...")
    corpora = rag.list_corpora()
    if not corpora:
        print("No RAG corpora found in this project/region.")
        print("Create one in Console or via API, then set RAG_CORPUS_NAME to use it.")
        sys.exit(1)
    for idx, corpus in enumerate(corpora, start=1):
        # corpus.name is the full resource name projects/{project}/locations/{location}/ragCorpora/{id}
        print(f"{idx}. {corpus.name}")
    print("\nSet environment variable RAG_CORPUS_NAME to the chosen corpus name and rerun.")
    sys.exit(0)
else:
    # Optional: verify the provided corpus exists
    corpora = rag.list_corpora()
    existing_names = {c.name for c in corpora}
    if rag_corpus_name not in existing_names:
        print(f"Provided RAG_CORPUS_NAME not found: {rag_corpus_name}")
        print("Available corpora:")
        for idx, corpus in enumerate(corpora, start=1):
            print(f"{idx}. {corpus.name}")
        sys.exit(1)
    print(f"Using existing corpus: {rag_corpus_name}")


# --- 4. Create the RAG Retrieval Tool ---
# This connects your corpus to the model
print("Creating RAG retrieval tool...")
rag_retrieval_tool = Tool.from_retrieval(
    retrieval=rag.Retrieval(
        source=rag.VertexRagStore(
            rag_resources=[
                rag.RagResource(
                    rag_corpus=rag_corpus_name,
                )
            ]
        ),
    )
)

# --- 5. Create a Gemini Model with the RAG Tool ---
print("Initializing Gemini model...")
model = GenerativeModel(
    model_name=MODEL_NAME,
    tools=[rag_retrieval_tool]
)

# --- 6. Ask a Question! ---
# The model will automatically use the RAG tool to find
# context from your document before answering.
question = "What is the main topic of my document?" # 👈 Ask a question
print(f"\nAsking question: {question}\n")

response = model.generate_content(question)

print("--- Answer ---")
print(response.text)
print("---------------")