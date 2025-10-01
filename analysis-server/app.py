# app.py
import os
import time
import re
from uuid import uuid4
from flask import Flask, request, jsonify
from flask_cors import CORS

import services
from config import UPLOAD_DIR, ALLOWED_AUDIO, ALLOWED_IMAGE
from services import media
import services.kobert as kobert
import services.fusion as fusion
# services.vision 은 7->5 동시 제공 버전(vision.analyze / analyze_video_weighted) 사용

app = Flask(__name__)
CORS(app)

os.makedirs(UPLOAD_DIR, exist_ok=True)
app.config["MAX_CONTENT_LENGTH"] = int(os.getenv("MAX_CONTENT_MB", "200")) * 1024 * 1024

# ---------------- Helper: 명시적 '기쁨' 표현 탐지 ----------------
_POS_EXPLICIT = [
    r"기뻤[다요]?", r"기쁘[다요]?", r"행복했[다요]?", r"행복하[다요]?",
    r"좋았[다요]?", r"좋아[요]?", r"즐거웠[다요]?", r"재밌었[다요]?",
    r"완전\s*좋", r"짱\s*좋", r"개\s*행복", r"행복\s*그자체"
]

def _explicit_emotion(text: str) -> str | None:
    t = (text or "").strip().lower()
    if not t:
        return None
    for pat in _POS_EXPLICIT:
        if re.search(pat, t):
            return "joy"
    return None
# -----------------------------------------------------------------

@app.route("/", methods=["GET"])
def root():
    return "Analysis Server is running!"

@app.route("/health", methods=["GET"])
def health():
    ok_whisper = hasattr(services.stt, "_model") and (services.stt._model is not None)
    try:
        _ = kobert.predict("테스트")
        ok_kobert = True
    except Exception:
        ok_kobert = False
    return jsonify({"ok": True, "models": {
        "whisper": ok_whisper,
        "kobert": ok_kobert,
        "deepface": "ok"
    }}), 200

@app.route("/analyze/text", methods=["POST"])
def analyze_text():
    data = request.get_json(silent=True) or {}
    text = (data.get("text") or "").strip()
    dist5 = kobert.predict(text)          # 5감정
    raw7  = kobert.predict7(text)         # 7감정
    return jsonify({"type": "text", "text": text, "distribution": dist5, "raw7": raw7}), 200

@app.route("/analyze/file", methods=["POST"])
def analyze_file():
    t0 = time.time()

    if "file" not in request.files:
        return jsonify({"ok": False, "error": "file field is required"}), 400

    f = request.files["file"]
    orig_name = (f.filename or "").strip()
    if not orig_name:
        return jsonify({"ok": False, "error": "empty filename"}), 400

    _, ext = os.path.splitext(orig_name)
    ext = ext.lower()

    if ext in ALLOWED_IMAGE:
        kind = "image"
    elif ext in ALLOWED_AUDIO:
        kind = "audio"
    elif ext in {".mp4", ".mov", ".avi", ".mkv"}:
        kind = "video"
    else:
        return jsonify({"ok": False, "error": f"unsupported file type: {ext}"}), 415

    safe_name = f"{uuid4().hex}{ext}"
    save_path = os.path.join(UPLOAD_DIR, safe_name)
    f.save(save_path)

    warnings = []
    try:
        # ---------- IMAGE ----------
        if kind == "image":
            face = services.vision.analyze(save_path)  # returns emotion, scores7, scores5
            return jsonify({
                "ok": True,
                "type": "image",
                "file": safe_name,
                "emotion": face.get("emotion"),
                "details": {
                    "face": {
                        "scores7": face.get("scores7", {}),  # 7 emotions (angry..neutral)
                        "scores5": face.get("scores5", {})   # 5 emotions (fusion-ready)
                    }
                },
                "metrics": {"elapsed_ms": int((time.time() - t0) * 1000)}
            }), 200

        # ---------- AUDIO ----------
        if kind == "audio":
            txt_pack = services.stt.transcribe(save_path)
            text = txt_pack.get("text", "")
            segments = txt_pack.get("segments", [])

            if segments:
                text_dist5 = kobert.predict_segments(segments)  # 5감정(길이 가중 평균)
            else:
                text_dist5 = kobert.predict(text)
            raw7 = kobert.predict7(text)

            if not text:
                warnings.append("no_voice_detected")

            return jsonify({
                "ok": True,
                "type": "audio",
                "file": safe_name,
                "text": {"transcript": text, "distribution": text_dist5, "raw7": raw7},
                "metrics": {"elapsed_ms": int((time.time() - t0) * 1000)},
                "warnings": warnings
            }), 200

        # ---------- VIDEO ----------
        if kind == "video":
            # 1) 얼굴: 7감정(raw7) + 5감정(scores5) 동시 산출
            vpack = services.vision.analyze_video_weighted(save_path, sample_sec=0.5, max_frames=180)
            emotions   = vpack.get("timeline", [])
            face_raw7  = vpack.get("scores7", {})  # 7 emotions
            face_dist5 = vpack.get("scores5", {"joy":0,"sad":0,"anger":0,"neutral":1,"surprise":0})
            duration_est = float(vpack.get("duration_est", 0.0))
            if not emotions:
                warnings.append("no_face_detected")

            # 2) 오디오 → STT → 텍스트 감정
            transcript, segments = "", []
            text_dist5 = {"joy":0.0,"sad":0.0,"anger":0.0,"neutral":1.0,"surprise":0.0}
            speech_ratio = None
            if media.has_audio(save_path):
                wav_path = media.extract_wav(save_path, UPLOAD_DIR)
                if wav_path and os.path.exists(wav_path):
                    txt_pack = services.stt.transcribe(wav_path)
                    transcript = txt_pack.get("text", "") or ""
                    segments   = txt_pack.get("segments", []) or []
                    if segments:
                        text_dist5 = kobert.predict_segments(segments)
                        voiced = sum(max(0.0, s.get("end",0)-s.get("start",0)) for s in segments)
                        if duration_est > 0:
                            speech_ratio = max(0.0, min(1.0, voiced / duration_est))
                    else:
                        text_dist5 = kobert.predict(transcript)
                    try: os.remove(wav_path)
                    except: pass
                else:
                    warnings.append("audio_extract_failed")
            else:
                warnings.append("no_voice_detected")

            # 3) Fusion — 텍스트 우선 규칙 (항상 5감정으로 합성)
            if speech_ratio is not None:
                a = 0.5 + 0.4 * float(speech_ratio)   # 0.5~0.9
            else:
                a = 0.7
            b = 1.0 - a

            text_top = max(text_dist5, key=text_dist5.get)
            face_top = max(face_dist5, key=face_dist5.get)
            text_conf = float(text_dist5.get(text_top, 0.0))
            face_conf = float(face_dist5.get(face_top, 0.0))

            # 텍스트 확신 부스터
            if (text_conf - face_conf) >= 0.25:
                a += 0.12
            # 명시적 '기쁨' 표현이면 추가 부스터
            if _explicit_emotion(transcript) == "joy":
                a += 0.10
            # 상충(텍스트 joy vs 얼굴 sad/anger) 시 말 신뢰
            if text_top == "joy" and face_top in ("sad", "anger"):
                a += 0.08

            a = min(0.95, max(0.5, a))
            b = 1.0 - a

            fused = fusion.fuse(text_dist5, face_dist5, alpha=a, beta=b)

            return jsonify({
                "ok": True,
                "type": "video",
                "file": safe_name,
                "text": {
                    "transcript": transcript,
                    "distribution": text_dist5,                 # 5 emotions (fusion input)
                    "raw7": kobert.predict7(transcript) if transcript else {}
                },
                "face": {
                    "timeline": emotions,
                    "distribution": face_dist5,                 # 5 emotions (fusion input)
                    "raw7": face_raw7                           # 7 emotions (viz)
                },
                "fused": fused,                                  # final 5 emotions
                "warnings": warnings,
                "metrics": {
                    "elapsed_ms": int((time.time() - t0) * 1000),
                    "speech_ratio": speech_ratio,
                    "frames": vpack.get("frames", 0)
                }
            }), 200

    except Exception as e:
        return jsonify({
            "ok": False,
            "error": str(e),
            "metrics": {"elapsed_ms": int((time.time() - t0) * 1000)}
        }), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)
