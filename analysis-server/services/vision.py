# services/vision.py
import os
os.environ["TF_USE_LEGACY_KERAS"] = "0"

import cv2
from deepface import DeepFace

EMO7 = ["angry", "disgust", "fear", "happy", "sad", "surprise", "neutral"]
EMO5 = ["joy", "sad", "anger", "neutral", "surprise"]

def _laplacian_var(img_bgr):
    try:
        gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
        return float(cv2.Laplacian(gray, cv2.CV_64F).var())
    except Exception:
        return 0.0

def _area_weight(region):
    if not region: return 0.0
    w = float(region.get("w", 0) or 0)
    h = float(region.get("h", 0) or 0)
    return max(0.0, w * h)

def _norm7(d7: dict) -> dict:
    s = sum(float(d7.get(k,0.0)) for k in EMO7) or 1.0
    return {k: float(d7.get(k,0.0))/s for k in EMO7}

def _map7_to5(d7: dict) -> dict:
    return {
        "joy":      float(d7.get("happy", 0.0)),
        "sad":      float(d7.get("sad", 0.0)) + float(d7.get("fear", 0.0)),
        "anger":    float(d7.get("angry", 0.0)) + float(d7.get("disgust", 0.0)),
        "neutral":  float(d7.get("neutral", 0.0)),
        "surprise": float(d7.get("surprise", 0.0)),
    }

def _norm5(d5: dict) -> dict:
    s = sum(float(d5.get(k,0.0)) for k in EMO5) or 1.0
    return {k: float(d5.get(k,0.0))/s for k in EMO5}

def _analyze_frame(frame_bgr):
    rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
    try:
        res = DeepFace.analyze(
            img_path=rgb, actions=['emotion'],
            detector_backend='retinaface', enforce_detection=True
        )
    except Exception:
        try:
            res = DeepFace.analyze(
                img_path=rgb, actions=['emotion'],
                detector_backend='opencv', enforce_detection=False   # ✅ 폴백
            )
        except Exception:
            return None
    rec = res[0] if isinstance(res, list) else res
    scores7 = rec.get("emotion", {}) or {}
    region  = rec.get("region", {}) or {}
    return _norm7(scores7), region

def analyze(image_path: str) -> dict:
    try:
        result = DeepFace.analyze(
            img_path=image_path, actions=['emotion'],
            detector_backend='retinaface', enforce_detection=True
        )
    except Exception:
        try:
            result = DeepFace.analyze(
                img_path=image_path, actions=['emotion'],
                detector_backend='opencv', enforce_detection=False      # ✅ 폴백
            )
        except Exception as e:
            return {"emotion": "neutral", "scores7": {}, "scores5": {}, "faces": [], "error": str(e)}

    rec = result[0] if isinstance(result, list) else result
    raw7 = _norm7(rec.get('emotion', {}) or {})
    dist5 = _norm5(_map7_to5(raw7))
    dom = max(dist5, key=dist5.get)
    return {"emotion": dom, "scores7": raw7, "scores5": dist5, "faces": []}

def analyze_video_weighted(path: str, sample_sec: float = 1.0, max_frames: int = 180):
    cap = cv2.VideoCapture(path)
    if not cap.isOpened():
        return {"timeline": [], "scores7": {}, "scores5": {}, "frames": 0, "duration_est": 0.0}

    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    step = max(int(fps * sample_sec), 1)

    agg7 = {k: 0.0 for k in EMO7}
    timeline = []
    taken, idx = 0, 0

    while True:
        ret = cap.grab()
        if not ret: break
        if idx % step == 0:
            ret2, frame = cap.retrieve()
            if not ret2: break

            lp = _laplacian_var(frame)
            r = _analyze_frame(frame)
            if r is None:
                timeline.append("neutral")
            else:
                scores7, region = r
                w_area = _area_weight(region)
                w_focus = min(lp / 150.0, 1.0)
                w = max(1e-6, w_area * (0.5 + 0.5*w_focus))
                for k in EMO7:
                    agg7[k] += w * float(scores7.get(k, 0.0))
                dist5 = _map7_to5(scores7)
                dom = max(dist5, key=dist5.get) if dist5 else "neutral"
                timeline.append(dom)

            taken += 1
            if taken >= max_frames: break
        idx += 1
    cap.release()

    agg7["neutral"] *= 0.9
    agg7["surprise"] *= 0.95

    raw7 = _norm7(agg7)
    dist5 = _norm5(_map7_to5(raw7))
    duration_est = taken * sample_sec

    return {"timeline": timeline, "scores7": raw7, "scores5": dist5,
            "frames": taken, "duration_est": float(duration_est)}
