# app.py
import os, re, time, logging
from uuid import uuid4
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

from services.db import init_db, save_analysis_result, get_results_by_day, get_results_in_range
from config import UPLOAD_DIR, ALLOWED_AUDIO, ALLOWED_IMAGE

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_CACHE_DIR = os.getenv("MODEL_CACHE_DIR", os.path.join(BASE_DIR, "models"))
os.makedirs(MODEL_CACHE_DIR, exist_ok=True)
os.environ.setdefault("HF_HOME", MODEL_CACHE_DIR)
os.environ.setdefault("TRANSFORMERS_CACHE", MODEL_CACHE_DIR)
os.environ.setdefault("TORCH_HOME", MODEL_CACHE_DIR)
os.makedirs(UPLOAD_DIR, exist_ok=True)

LOG_DIR = os.path.join(BASE_DIR, "logs"); os.makedirs(LOG_DIR, exist_ok=True)
logger = logging.getLogger("analysis-server")
logger.setLevel(logging.INFO)
if not logger.handlers:
    fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
    fh = logging.FileHandler(os.path.join(LOG_DIR, "server.log"), encoding="utf-8")
    ch = logging.StreamHandler()
    fh.setFormatter(fmt); ch.setFormatter(fmt)
    logger.addHandler(fh); logger.addHandler(ch)

logger.info("=== Analysis Server boot ===")
logger.info(f"MODEL_CACHE_DIR={MODEL_CACHE_DIR}")

# 모델/서비스
from services import media
import services.kobert as kobert
import services.fusion as fusion
import services.stt as stt
import services.vision as vision
import services.s3uploader as s3uploader
import services.gpt as gpt

app = Flask(__name__)
CORS(app)
app.config["MAX_CONTENT_LENGTH"] = int(os.getenv("MAX_CONTENT_MB", "200")) * 1024 * 1024

# 명시적 긍정 표현 패턴
_POS_EXPLICIT = [
    r"기뻤[다요]?", r"기쁘[다요]?", r"행복했[다요]?", r"행복하[다요]?",
    r"좋았[다요]?", r"좋아[요]?", r"즐거웠[다요]?", r"재밌었[다요]?",
    r"완전\s*좋", r"짱\s*좋", r"개\s*행복", r"행복\s*그자체",
    r"미칠\s*만큼\s*좋", r"기뻐\s*죽겠", r"행복\s*터지",
]
def _explicit_emotion(text: str) -> str | None:
    t = (text or "").strip().lower()
    if not t: return None
    for pat in _POS_EXPLICIT:
        if re.search(pat, t): return "joy"
    return None

def _sha1(path: str) -> str:
    import hashlib
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1<<20), b""):
            h.update(b)
    return h.hexdigest()

@app.get("/")
def root(): return "Analysis Server is running."

@app.get("/health")
def health():
    ok_whisper = hasattr(stt, "_model") and (stt._model is not None)
    try: _ = kobert.predict("테스트"); ok_kobert = True
    except Exception: ok_kobert = False
    return jsonify({"ok": True, "models": {"whisper": ok_whisper, "kobert": ok_kobert, "deepface":"ok"}}), 200

@app.post("/analyze/file")
def analyze_file():
    t0 = time.time()
    if "file" not in request.files:
        return jsonify({"ok": False, "error": "file field is required"}), 400

    f = request.files["file"]
    orig = (f.filename or "").strip()
    if not orig: return jsonify({"ok": False, "error": "empty filename"}), 400
    _, ext = os.path.splitext(orig); ext = ext.lower()

    if   ext in ALLOWED_IMAGE: kind = "image"
    elif ext in ALLOWED_AUDIO: kind = "audio"
    elif ext in {".mp4",".mov",".avi",".mkv"}: kind = "video"
    else: return jsonify({"ok": False, "error": f"unsupported file type: {ext}"}), 415

    safe = f"{uuid4().hex}{ext}"
    path = os.path.join(UPLOAD_DIR, safe)
    f.save(path)
    logger.info(f"uploaded: {orig} -> {path} ({kind})")

    s3_key = None
    try: s3_key = s3uploader.upload_async(path, safe)
    except Exception as e: logger.warning(f"S3 upload warn: {e}")

    warnings = []
    try:
        if kind == "image":
            face = vision.analyze(path) or {}
            face_dist5 = face.get("distribution") or face.get("scores5") or {"joy":0,"sad":0,"anger":0,"neutral":1,"surprise":0}
            if sum(face_dist5.values()) == 0: warnings.append("no_face_detected")
            result = {"type":"image","face":{"distribution": face_dist5, "raw7": face.get("raw7", {})}}

        elif kind == "audio":
            pack = stt.transcribe(path)
            text = pack.get("text",""); segs = pack.get("segments",[])
            text_dist5 = kobert.predict_segments(segs) if segs else kobert.predict(text)
            raw7 = kobert.predict7(text)
            if not text: warnings.append("no_voice_detected")
            result = {"type":"audio","text":{"transcript": text,"distribution": text_dist5,"raw7": raw7}}

        else:
            vpack = vision.analyze_video_weighted(path, sample_sec=0.5, max_frames=180)
            face_raw7  = vpack.get("scores7", {})
            face_dist5 = vpack.get("scores5", {"joy":0,"sad":0,"anger":0,"neutral":1,"surprise":0})
            timeline   = vpack.get("timeline", [])
            if not timeline: warnings.append("no_face_detected")

            transcript, segs = "", []
            text_dist5 = {"joy":0,"sad":0,"anger":0,"neutral":1,"surprise":0}
            if media.has_audio(path):
                wav = media.extract_wav(path, UPLOAD_DIR)
                if wav and os.path.exists(wav):
                    tp = stt.transcribe(wav)
                    transcript = tp.get("text","") or ""
                    segs = tp.get("segments",[]) or []
                    text_dist5 = kobert.predict_segments(segs) if segs else kobert.predict(transcript)
                    try: os.remove(wav)
                    except: pass
            else: warnings.append("no_voice_detected")

            # ★ 명시적 '기쁨' 표현 시 텍스트 가중 상향
            a = 0.7
            if _explicit_emotion(transcript) == "joy":
                a = min(0.95, 0.85)

            fused = fusion.fuse(text_dist5, face_dist5, alpha=a, beta=1-a)

            result = {
                "type":"video",
                "text":{"transcript": transcript,"distribution": text_dist5,
                        "raw7": kobert.predict7(transcript) if transcript else {}},
                "face":{"timeline": timeline,"distribution": face_dist5,"raw7": face_raw7},
                "fused": fused
            }

        # (옵션) GPT 피드백
        try:
            kdate = time.strftime("%Y년 %m월 %d일")
            typ = result.get("type")
            if   typ == "video": fused_dist = (result.get("fused") or {}).get("distribution") or {}
            elif typ == "audio": fused_dist = (result.get("text") or {}).get("distribution") or {}
            else:                fused_dist = (result.get("face") or {}).get("distribution") \
                                            or (result.get("face") or {}).get("scores5") or {}
            transcript = (result.get("text") or {}).get("transcript","") or ""
            fb = gpt.make_feedback(kdate, fused_dist, transcript)
            if fb: result["feedback"] = fb
        except Exception as e:
            logger.warning(f"GPT feedback skipped: {e}")

        resp = {
            "ok": True,
            "file": safe,
            "s3_key": s3_key,
            "result": result,
            "warnings": warnings,
            "metrics": {"elapsed_ms": int((time.time()-t0)*1000)},
            "debug": {
                "kind": kind,
                "file_sha1": _sha1(path),
                "file_size": os.path.getsize(path),
                "has_transcript": bool((result.get("text") or {}).get("transcript")),
                "has_timeline": bool((result.get("face") or {}).get("timeline")),
                "top_label": (result.get("fused") or {}).get("final_label"),
                "warnings": warnings,
            }
        }

        transcript_for_db = (result.get("text") or {}).get("transcript","") if result.get("type")!="image" else ""
        save_analysis_result(kind, safe, result, transcript_for_db)
        logger.info(f"done: {safe} in {resp['metrics']['elapsed_ms']}ms")
        return jsonify(resp), 200

    except Exception as e:
        logger.exception("analysis failed")
        return jsonify({"ok": False, "error": str(e), "file": safe}), 500


@app.get("/results/day")
def results_day():
    date = request.args.get("date"); user_id = request.args.get("user_id") or None
    return jsonify(get_results_by_day(date, user_id)), 200

@app.get("/results/range")
def results_range():
    start = request.args.get("start"); end = request.args.get("end")
    user_id = request.args.get("user_id") or None
    return jsonify(get_results_in_range(start, end, user_id)), 200

# === 주간 리포트 + GPT 피드백 ===
@app.get("/report/weekly")
def report_weekly():
    start = request.args.get("start")
    end = request.args.get("end")
    user_id = request.args.get("user_id") or None

    if not start or not end:
        return jsonify({"ok": False, "error": "start/end required"}), 400

    rows = get_results_in_range(start, end, user_id)

    if not rows:
        return jsonify({"ok": False, "error": "no data in range"}), 404

    # 평균 산출 (fused.distribution 우선)
    joy=sad=ang=sur=neu=0.0; n=0
    for e in rows:
        emo = e.get("emotion")
        dist = None
        if isinstance(emo, dict):
            if (emo.get("fused") or {}).get("distribution"):
                dist = emo["fused"]["distribution"]
            elif (emo.get("face") or {}).get("distribution"):
                dist = emo["face"]["distribution"]
            elif (emo.get("text") or {}).get("distribution"):
                dist = emo["text"]["distribution"]
        if not dist:
            continue
        joy += float(dist.get("joy", 0.0)) * 100.0
        sad += float(dist.get("sad", 0.0)) * 100.0
        ang += float(dist.get("anger", 0.0)) * 100.0
        neu += float(dist.get("neutral", 0.0)) * 100.0
        sur += float(dist.get("surprise", 0.0)) * 100.0
        n += 1

    if n == 0:
        return jsonify({"ok": False, "error": "no usable rows"}), 404

    avg_pct = {
        "joy":      joy/n/100.0,
        "sad":      sad/n/100.0,
        "anger":    ang/n/100.0,
        "surprise": sur/n/100.0,
        "neutral":  neu/n/100.0,
    }

    # GPT 주간 피드백 (요약 3~5문장 + 행동1~3)
    try:
        fb = gpt.make_weekly_feedback(start, end, avg_pct, sample_count=n)
    except Exception as e:
        fb = None

    return jsonify({
        "ok": True,
        "range": {"start": start, "end": end, "count": n},
        "avg_distribution": avg_pct,   # 0~1 분포
        "gpt_feedback": fb or "",
    }), 200


try:
    init_db(); logger.info("✅ DB schema ready.")
except Exception:
    logger.exception("❌ DB init failed")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=False, threaded=True)
