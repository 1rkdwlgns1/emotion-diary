# config.py (교체)
# 환경변수 및 설정값 관리
# - UPLOAD_DIR: 업로드 폴더 (기본: ./uploads)
# - ALLOWED_AUDIO: 허용 오디오 확장자 (기본: .wav, .mp3, .m4a)
# - ALLOWED_IMAGE: 허용 이미지 확장자 (기본: .jpg, .jpeg, .png)

import os
from dotenv import load_dotenv
load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
AZURE_FACE_ENDPOINT = os.getenv("AZURE_FACE_ENDPOINT", "").rstrip("/")
AZURE_FACE_KEY = os.getenv("AZURE_FACE_KEY", "")

BASE_DIR = os.path.dirname(__file__)
UPLOAD_DIR = os.path.join(BASE_DIR, os.getenv("UPLOAD_DIR", "uploads"))  # ← env 반영

def _extset(envkey: str, default: set[str]) -> set[str]:
    raw = os.getenv(envkey, "")
    if not raw:
        return default
    parts = [p.strip().lower() for p in raw.split(",") if p.strip()]
    return {"." + p.lstrip(".") for p in parts}

ALLOWED_AUDIO = _extset("ALLOWED_AUDIO", {".wav", ".mp3", ".m4a"})
ALLOWED_IMAGE = _extset("ALLOWED_IMAGE", {".jpg", ".jpeg", ".png"})
