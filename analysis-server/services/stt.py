import os
import whisper
import torch

_model = None

def _load(model_name: str | None = None):
    """Whisper 모델 CPU 강제 로딩"""
    global _model
    if _model is None:
        name = model_name or os.getenv("WHISPER_MODEL", "small")
        _model = whisper.load_model(name, device="cpu")  # ✅ CPU 강제
    return _model

def transcribe(audio_path: str) -> dict:
    try:
        m = _load()
        out = m.transcribe(
            audio_path,
            fp16=False,
            language="ko",
            beam_size=3,
            best_of=3,
            temperature=0.0,
            condition_on_previous_text=True,
            no_speech_threshold=0.3,
            logprob_threshold=-1.2,
            initial_prompt="한국어 발화를 정확하게 받아적으세요."
        )

        text = (out.get("text") or "").strip()
        segs = []
        for s in (out.get("segments") or []):
            segs.append({
                "start": float(s.get("start", 0)),
                "end": float(s.get("end", 0)),
                "text": s.get("text", "") or ""
            })
        return {"text": text, "segments": segs}

    except Exception as e:
        print("[STT error]", e)
        return {"text": "", "segments": []}
