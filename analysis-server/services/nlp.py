def analyze(text: str):
    text = (text or "").strip()
    if not text:
        return {"emotion": "neutral", "score": 0.0, "text": text}

    low = text.lower()

    if any(k in low for k in ["화나", "짜증", "열받"]):
        return {"emotion": "angry", "score": 0.9, "text": text}

    if any(k in low for k in ["기쁘", "좋아", "행복"]):
        return {"emotion": "happy", "score": 0.9, "text": text}

    if any(k in low for k in ["슬프", "우울", "눈물"]):
        return {"emotion": "sad", "score": 0.85, "text": text}

    return {"emotion": "neutral", "score": 0.5, "text": text}
