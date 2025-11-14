"""
List available Vertex AI models in a given region.
Uses Application Default Credentials (gcloud auth application-default login).
"""
import os
import sys
from google import genai
from google.genai import types


def list_models(project_id: str, location: str) -> None:
    """List available models in the specified project and location."""
    print(f"Listing models in project={project_id}, location={location}...")
    print("-" * 80)
    
    # Initialize client with ADC (no API key needed)
    client = genai.Client(
        vertexai=True,
        project=project_id,
        location=location,
    )
    
    try:
        # List all models
        models = list(client.models.list())
        
        if not models:
            print("No models found.")
            return
        
        print(f"Found {len(models)} model(s):\n")
        
        # Filter and display Gemini/text models (not Imagen)
        gemini_models = []
        other_models = []
        
        for model in models:
            model_name = getattr(model, "name", None) or getattr(model, "model", None) or str(model)
            
            # Extract just the model identifier (e.g., "gemini-1.5-flash-002")
            if "/models/" in model_name:
                short_name = model_name.split("/models/")[-1]
            else:
                short_name = model_name
            
            # Check if it's a Gemini model
            if "gemini" in short_name.lower():
                gemini_models.append(short_name)
            else:
                other_models.append((short_name, model_name))
        
        if gemini_models:
            print("=== Gemini Models (for text generation with RAG) ===")
            for model in sorted(set(gemini_models)):
                print(f"  {model}")
            print()
        
        if other_models:
            print("=== Other Models ===")
            for short_name, full_name in other_models:
                print(f"  {short_name}")
                print(f"    Full name: {full_name}")
            print()
        
        # Also try to get model info if available
        print("\n=== Usage Example ===")
        if gemini_models:
            example_model = sorted(set(gemini_models))[0]
            print(f"export MODEL_NAME=\"{example_model}\"")
            print("python preview.py")
        else:
            print("No Gemini models found. You may need to:")
            print("  1. Enable Vertex AI API")
            print("  2. Request access to Gemini models")
            print("  3. Try a different region (e.g., us-central1, europe-west1)")
        
    except Exception as e:
        print(f"Error listing models: {e}")
        print("\nTroubleshooting:")
        print("  1. Ensure Vertex AI API is enabled:")
        print("     gcloud services enable aiplatform.googleapis.com")
        print("  2. Check your authentication:")
        print("     gcloud auth application-default login")
        print("  3. Verify project and region:")
        print(f"     gcloud config get-value project")
        sys.exit(1)


def main() -> None:
    project_id = os.getenv("PROJECT_ID", "appier-airis-tstc")
    location = os.getenv("LOCATION", "asia-east1")
    
    # Allow command line override
    if len(sys.argv) > 1:
        location = sys.argv[1]
    if len(sys.argv) > 2:
        project_id = sys.argv[2]
    
    list_models(project_id, location)


if __name__ == "__main__":
    main()

