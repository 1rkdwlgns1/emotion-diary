#STT Whisper 자리

import os
from openai import OpenAI
from config import OPENAI_API_KEY

_client = None

def _client_once():
    global _client
    if _client is None:
        _client = OpenAI(api_key=OPENAI_API_KEY)
    return _client

def transcribe(audio_path: str) -> str:
    """
    audio_path: .wav/.mp3/.m4a 같은 로컬 파일 경로
    반환: 인식된 텍스트(str). 실패 시 빈 문자열.
    """
    if not OPENAI_API_KEY:
        return ""

    client = _client_once()
    with open(audio_path, "rb") as f:
        try:
            resp = client.audio.transcriptions.create(
                model="whisper-1",
                file=f
            )
            # SDK 버전에 따라 resp.text 또는 resp["text"]
            return getattr(resp, "text", "") or resp.get("text", "")
        except Exception as e:
            print("[Whisper] error:", e)
            return ""
