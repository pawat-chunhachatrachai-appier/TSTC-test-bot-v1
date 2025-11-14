# list_rag_corpora.py
import os
from typing import Optional

import vertexai
from vertexai.preview import rag
from google.auth import default as adc_default

def get_project_id() -> str:
    env_project = os.getenv("PROJECT_ID")
    if env_project:
        return env_project
    creds, project_id = adc_default()
    if not project_id:
        raise RuntimeError("PROJECT_ID not set and ADC has no project. Run: gcloud config set project YOUR_PROJECT")
    return project_id

def main() -> None:
    project_id = get_project_id()
    location = os.getenv("LOCATION1", "us-east1")
    location = "asia-east1"
    project_id = "appier-airis-tstc"

    vertexai.init(project=project_id, location=location)
    corpora = rag.list_corpora()

    if not corpora:
        print(f"No RAG corpora found in project={project_id}, location={location}")
        return

    print(f"RAG corpora in project={project_id}, location={location}:")
    for i, c in enumerate(corpora, start=1):
        name = getattr(c, "name", "")
        display = getattr(c, "display_name", getattr(c, "displayName", ""))
        created = getattr(c, "create_time", getattr(c, "createTime", ""))
        print(f"{i}. name={name}")
        if display:
            print(f"   display_name={display}")
        if created:
            print(f"   create_time={created}")

if __name__ == "__main__":
    main()