from collections import Counter

_KEYS = ["joy", "sad", "anger", "neutral", "surprise"]

def _norm(d: dict) -> dict:
    s = sum(d.get(k, 0.0) for k in _KEYS) or 1.0
    return {k: float(d.get(k, 0.0)) / s for k in _KEYS}

def face_dist_from_timeline(timeline: list[str]) -> dict:
    # deepface: angry, disgust, fear, happy, sad, surprise, neutral
    cnt = Counter(timeline or [])
    d = {
        "joy":      cnt.get("happy", 0),
        "sad":      cnt.get("sad", 0) + cnt.get("fear", 0),
        "anger":    cnt.get("angry", 0) + cnt.get("disgust", 0),
        "neutral":  cnt.get("neutral", 0),
        "surprise": cnt.get("surprise", 0),
    }
    return _norm(d)

def fuse(text: dict, face: dict, alpha: float | None = None, beta: float | None = None) -> dict:
    """
    기본 가중치: 텍스트 0.7 / 얼굴 0.3
    개선:
      - neutral 억제
      - confidence < 0.4 → 'uncertain'
      - tie-break (text vs face 다르고 차이 < 0.15) → 'mixed'
    """
    a = alpha if alpha is not None else 0.7
    b = beta if beta is not None else 0.3

    t = _norm(text or {})
    f = _norm(face or {})

    fused = {k: a * t.get(k, 0.0) + b * f.get(k, 0.0) for k in _KEYS}

    # neutral 억제
    fused["neutral"] *= 0.9

    fused = _norm(fused)
    label = max(fused, key=fused.get)
    conf = fused[label]

    # 불확실성 처리
    if conf < 0.4:
        label = "uncertain"

    # tie-break 처리
    text_top = max(t, key=t.get)
    face_top = max(f, key=f.get)
    if text_top != face_top and abs(t.get(text_top, 0) - f.get(face_top, 0)) < 0.15:
        label = "mixed"

    return {"final_label": label, "confidence": conf, "fused": fused}
