# config.py
import os
from dotenv import load_dotenv

load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
AZURE_FACE_ENDPOINT = os.getenv("AZURE_FACE_ENDPOINT", "").rstrip("/")
AZURE_FACE_KEY = os.getenv("AZURE_FACE_KEY", "")

BASE_DIR = os.path.dirname(__file__)
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")

def _extset(envkey: str, default: set[str]) -> set[str]:
    raw = os.getenv(envkey, "")
    if not raw:
        return default
    parts = [p.strip().lower() for p in raw.split(",") if p.strip()]
    # app.py에서 ext는 ".jpg" 형태이므로 여기서 점을 붙여 통일
    return {"." + p.lstrip(".") for p in parts}

ALLOWED_AUDIO = _extset("ALLOWED_AUDIO", {".wav", ".mp3", ".m4a"})
ALLOWED_IMAGE = _extset("ALLOWED_IMAGE", {".jpg", ".jpeg", ".png"})
