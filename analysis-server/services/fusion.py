from collections import Counter

_KEYS = ["joy", "sad", "anger", "neutral", "surprise"]

def _norm(d: dict) -> dict:
    s = sum(float(d.get(k, 0.0)) for k in _KEYS) or 1.0
    return {k: float(d.get(k, 0.0)) / s for k in _KEYS}

def face_dist_from_timeline(tl: list[str]) -> dict:
    c = Counter(tl or [])
    d = {
        "joy": c.get("happy", 0),
        "sad": c.get("sad", 0) + c.get("fear", 0),
        "anger": c.get("angry", 0) + c.get("disgust", 0),
        "neutral": c.get("neutral", 0),
        "surprise": c.get("surprise", 0),
    }
    return _norm(d)

def fuse(text: dict, face: dict, alpha: float | None = None, beta: float | None = None) -> dict:
    a = alpha if alpha is not None else 0.85 
    b = beta  if beta  is not None else 0.15   
    t = _norm(text or {})
    f = _norm(face or {})

    fused = {k: a*t.get(k,0.0) + b*f.get(k,0.0) for k in _KEYS}

    fused["neutral"] *= 0.9
    fused = _norm(fused)

    label = max(fused, key=fused.get)
    conf  = fused[label]

    final_label = label if conf >= 0.35 else "uncertain"

    text_top = max(t, key=t.get) if t else None
    face_top = max(f, key=f.get) if f else None
    source_hint = "ok"
    if text_top and face_top:
        if text_top != face_top:
            source_hint = "conflict"
        else:
            source_hint = "agree"

    if text_top and face_top and text_top != face_top and abs(t[text_top]-f[face_top]) < 0.15:
        final_label = "mixed"

    return {
        "final_label": final_label,
        "confidence": conf,
        "distribution": fused,
        "source_hint": source_hint,
    }
