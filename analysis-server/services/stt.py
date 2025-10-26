# Whisper STT service
# Speech-to-Text transcription using Whisper

import os
import whisper
import torch

_model = None

def _load(model_name: str | None = None):
    global _model
    if _model is None:
        name = model_name or os.getenv("WHISPER_MODEL", "small")  # tiny/base/small/medium/large
        device = "cuda" if torch.cuda.is_available() else "cpu"
        _model = whisper.load_model(name, device=device)
    return _model

def transcribe(audio_path: str) -> dict:
    try:
        m = _load()
        out = m.transcribe(
            audio_path,
            fp16=False,
            language="ko",                 # 한국어 고정
            beam_size=5,
            best_of=5,
            temperature=0.0,               # 더 보수적으로
            condition_on_previous_text=True, # 이전 텍스트 문맥 사용 (연속성 ↑)
            no_speech_threshold=0.3,       # 무음 판정 완화(기본 0.6 근처 → 0.3)
            logprob_threshold=-1.2,        # 저신뢰 컷 완화
            initial_prompt="다음은 한국어 말하기의 정확한 자막입니다."  # 한글 편향
        )
        text = (out.get("text") or "").strip()
        segs = []
        for s in (out.get("segments") or []):
            segs.append({
                "start": float(s.get("start",0)),
                "end": float(s.get("end",0)),
                "text": s.get("text","") or ""
            })
        return {"text": text, "segments": segs}
    except Exception as e:
        print("[STT] error:", e)
        return {"text": "", "segments": []}
