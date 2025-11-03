# app.py  (완전판: 중복 분석 제거 + user_id 누락 해결 + GPT 피드백/퓨전/콜백 유지 + 추천 추가)
import os, re, time, logging, hashlib, requests
from uuid import uuid4
from flask import Flask, request, jsonify, g
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

from services.db import init_db, save_analysis_result
from config import UPLOAD_DIR, ALLOWED_AUDIO, ALLOWED_IMAGE

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_CACHE_DIR = os.getenv("MODEL_CACHE_DIR", os.path.join(BASE_DIR, "models"))
os.makedirs(MODEL_CACHE_DIR, exist_ok=True)
os.environ.setdefault("HF_HOME", MODEL_CACHE_DIR)
os.environ.setdefault("TRANSFORMERS_CACHE", MODEL_CACHE_DIR)
os.environ.setdefault("TORCH_HOME", MODEL_CACHE_DIR)
os.makedirs(UPLOAD_DIR, exist_ok=True)

LOG_DIR = os.path.join(BASE_DIR, "logs")
os.makedirs(LOG_DIR, exist_ok=True)
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

# ✅ Node 콜백 주소 + 전송 함수
NODE_RESULT_URL = os.getenv("NODE_RESULT_URL", "http://127.0.0.1:3000/analysis/result")

def _to_int_safe(x):
    try:
        return int(x)
    except Exception:
        return None

def send_result_to_node(request_id, user_id, media_id, result_data):
    """Flask → Node 분석결과 콜백 전송 (user_id/media_id 반드시 포함)"""
    try:
        payload = {
            "request_id": request_id,
            "user_id": user_id,
            "media_id": media_id,
            "result": result_data.get("result", result_data)
        }
        r = requests.post(NODE_RESULT_URL, json=payload, timeout=10)
        if r.status_code == 200:
            print(f"✅ Node에 결과 전송 완료 (request_id={request_id}, user_id={user_id}, media_id={media_id})")
        else:
            print(f"⚠️ Node 전송 실패: {r.status_code} {r.text}")
    except Exception as e:
        print(f"❌ Node 콜백 오류: {e}")

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
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1<<20), b""):
            h.update(b)
    return h.hexdigest()

@app.get("/")
def root():
    return "Analysis Server is running."

@app.get("/health")
def health():
    ok_whisper = hasattr(stt, "_model") and (stt._model is not None)
    try:
        _ = kobert.predict("테스트")
        ok_kobert = True
    except Exception:
        ok_kobert = False
    return jsonify({"ok": True, "models": {"whisper": ok_whisper, "kobert": ok_kobert, "deepface": "ok"}}), 200


# ==========================================================
# 🔧 공통 분석 함수 (중복 방지)
# ==========================================================
def _run_analysis(path: str, kind: str, user_id=None, media_id=None, request_id=None):
    """파일 경로와 종류를 받아 공통 분석 수행"""
    t0 = time.time()
    warnings = []
    result = {}

    try:
        if kind == "image":
            face = vision.analyze(path) or {}
            face_dist5 = face.get("distribution") or face.get("scores5") or {"joy":0,"sad":0,"anger":0,"neutral":1,"surprise":0}
            result = {"type":"image","face":{"distribution": face_dist5, "raw7": face.get("raw7", {})}}

        elif kind == "audio":
            pack = stt.transcribe(path)
            text = pack.get("text",""); segs = pack.get("segments",[])
            text_dist5 = kobert.predict_segments(segs) if segs else kobert.predict(text)
            raw7 = kobert.predict7(text)
            result = {"type":"audio","text":{"transcript": text,"distribution": text_dist5,"raw7": raw7}}

        else:  # video
            vpack = vision.analyze_video_weighted(path, sample_sec=0.5, max_frames=180)
            face_raw7  = vpack.get("scores7", {})
            face_dist5 = vpack.get("scores5", {"joy":0,"sad":0,"anger":0,"neutral":1,"surprise":0})
            timeline   = vpack.get("timeline", [])
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

        # GPT 피드백
        try:
            kdate = time.strftime("%Y년 %m월 %d일")
            typ = result.get("type")
            if   typ == "video": fused_dist = (result.get("fused") or {}).get("distribution") or {}
            elif typ == "audio": fused_dist = (result.get("text") or {}).get("distribution") or {}
            else: fused_dist = (result.get("face") or {}).get("distribution") or {}
            transcript = (result.get("text") or {}).get("transcript","") or ""
            fb = gpt.make_feedback(kdate, fused_dist, transcript)
            if fb: result["feedback"] = fb
        except Exception as e:
            logger.warning(f"GPT feedback skipped: {e}")

        debug_block = {
            "kind": kind,
            "file_sha1": _sha1(path),
            "file_size": os.path.getsize(path),
            "has_transcript": bool((result.get("text") or {}).get("transcript")),
            "has_timeline": bool((result.get("face") or {}).get("timeline")),
            "top_label": (result.get("fused") or {}).get("final_label"),
            "warnings": warnings,
        }

        resp = {
            "ok": True,
            "file": os.path.basename(path),
            "result": result,
            "warnings": warnings,
            "metrics": {"elapsed_ms": int((time.time()-t0)*1000)},
            "debug": debug_block,
            "context": {"user_id": user_id, "media_id": media_id, "request_id": request_id}
        }

        if user_id is not None and media_id is not None:
            req_id = _to_int_safe(request_id) or int(time.time())
            send_result_to_node(req_id, user_id, media_id, resp)

        return resp

    except Exception as e:
        logger.exception("analysis failed")
        return {"ok": False, "error": str(e)}


# ==========================================================
# 📁 /analyze/file — 직접 업로드
# ==========================================================
@app.post("/analyze/file")
def analyze_file():
    if "file" not in request.files:
        return jsonify({"ok": False, "error": "file field is required"}), 400

    f = request.files["file"]
    orig = (f.filename or "").strip()
    _, ext = os.path.splitext(orig); ext = ext.lower()

    if   ext in ALLOWED_IMAGE: kind = "image"
    elif ext in ALLOWED_AUDIO: kind = "audio"
    elif ext in {".mp4", ".mov", ".avi", ".mkv"}: kind = "video"
    else:
        return jsonify({"ok": False, "error": f"unsupported file type: {ext}"}), 415

    safe = f"{uuid4().hex}{ext}"
    path = os.path.join(UPLOAD_DIR, safe)
    f.save(path)
    logger.info(f"uploaded: {orig} -> {path} ({kind})")

    user_id   = _to_int_safe(request.form.get("user_id") or g.get("_user_id"))
    media_id  = _to_int_safe(request.form.get("media_id") or g.get("_media_id"))
    request_id = _to_int_safe(request.form.get("request_id"))

    result = _run_analysis(path, kind, user_id, media_id, request_id)
    return jsonify(result), 200


# ==========================================================
# 🪣 /analyze — Node → Flask (S3 기반)
# ==========================================================
@app.post("/analyze")
def analyze_from_s3():
    try:
        data = request.get_json() or {}
        s3_key    = data.get("s3_key") or data.get("s3Key")
        bucket    = data.get("bucket") or os.getenv("AWS_S3_BUCKET")
        user_id   = data.get("user_id") or data.get("userId")
        media_id  = data.get("media_id") or data.get("mediaId")
        request_id = data.get("request_id")

        print(f"📥 Node에서 분석 요청 받음: s3_key={s3_key}, user_id={user_id}, media_id={media_id}, request_id={request_id}")

        from services.s3uploader import download_from_s3
        local_path = download_from_s3(bucket, s3_key)
        if not local_path or not os.path.exists(local_path):
            return jsonify({"ok": False, "error": "파일 다운로드 실패"}), 500
        print(f"✅ S3에서 파일 다운로드 완료: {local_path}")

        _, ext = os.path.splitext(local_path); ext = ext.lower()
        if   ext in ALLOWED_IMAGE: kind = "image"
        elif ext in ALLOWED_AUDIO: kind = "audio"
        else: kind = "video"

        result = _run_analysis(
            local_path,
            kind,
            _to_int_safe(user_id),
            _to_int_safe(media_id),
            _to_int_safe(request_id) or int(time.time())
        )

        try: os.remove(local_path)
        except Exception as e: print(f"⚠️ 임시파일 삭제 실패: {e}")

        return jsonify(result), 200

    except Exception as e:
        import traceback; traceback.print_exc()
        return jsonify({"ok": False, "error": str(e)}), 500


# ==========================================================
# 🎵 /recommend/music — 감정 기반 음악 추천 (Flutter Today 화면용)
# ==========================================================
@app.get("/recommend/music")
def recommend_music():
    try:
        emotion = request.args.get("emotion") or "neutral"
        count = int(request.args.get("count", 3))
        user_id = request.args.get("user_id", "anon")
        day = request.args.get("day", time.strftime("%Y-%m-%d"))

        # GPT 기반 음악 추천
        try:
            items = gpt.make_music_recs(emotion=emotion, count=count)
        except Exception as e:
            print(f"⚠️ make_music_recs 오류: {e}")
            items = []

        return jsonify({
            "ok": True,
            "user_id": user_id,
            "day": day,
            "items": items
        }), 200
    except Exception as e:
        print(f"❌ /recommend/music 오류: {e}")
        return jsonify({"ok": False, "error": str(e)}), 500


# ==========================================================
# 🧘 /recommend/action — 감정 기반 활동 추천 (Flutter Today 화면용)
# ==========================================================
@app.get("/recommend/action")
def recommend_action():
    try:
        emotion = request.args.get("emotion") or "neutral"
        user_id = request.args.get("user_id", "anon")

        default_actions = {
            "joy": ["좋았던 순간을 메모로 남기기", "가벼운 산책하며 기분 유지하기"],
            "sad": ["따뜻한 차 마시며 휴식하기", "친한 사람에게 짧은 안부 메시지 보내기"],
            "anger": ["5분 복식호흡으로 긴장 풀기", "빠르게 걷기/가벼운 스트레칭 10분"],
            "surprise": ["새로운 음악 한 곡 탐색하기", "오늘의 놀란 순간 간단 기록하기"],
            "neutral": ["짧은 스트레칭으로 몸 깨우기", "좋아하는 음악 1곡 듣기"]
        }

        actions = default_actions.get(emotion, default_actions["neutral"])
        return jsonify({
            "ok": True,
            "user_id": user_id,
            "emotion": emotion,
            "actions": actions
        }), 200

    except Exception as e:
        print(f"❌ /recommend/action 오류: {e}")
        return jsonify({"ok": False, "error": str(e)}), 500


# ==========================================================
# 🧱 초기화 및 실행
# ==========================================================
try:
    logger.info("✅ Flask DB writes disabled; Node handles persistence.")
except Exception:
    logger.exception("❌ DB init failed")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=False, threaded=True)


# ============================
# ✅ 조회 API는 Node에서 담당
# ============================
# @app.get("/results/day")
# def results_day():
#     try:
#         date = request.args.get("date")
#         user_id = request.args.get("user_id") or None
#         if not date:
#             return jsonify({"ok": False, "error": "date required"}), 400
#         data = get_results_by_day(date, user_id)
#         return jsonify(data), 200
#     except Exception as e:
#         logger.exception("results_day failed")
#         return jsonify({"ok": False, "error": f"internal error: {str(e)}"}), 500

# === 안정화된 주간 범위 조회 ===
# @app.get("/results/range")
# def results_range():
#     try:
#         start = request.args.get("start")
#         end = request.args.get("end")
#         user_id = request.args.get("user_id") or None
#
#         if not start or not end:
#             return jsonify({"ok": False, "error": "start/end required"}), 400
#
#         # 너무 큰 범위 가드 (환경변수로 조절)
#         from datetime import datetime
#         _max_days = int(os.getenv("MAX_RANGE_DAYS", "62"))
#         sd = datetime.fromisoformat(start)
#         ed = datetime.fromisoformat(end)
#         if (ed - sd).days > _max_days:
#             return jsonify({"ok": False, "error": f"date range too large (>{_max_days} days)"}), 400
#
#         rows = get_results_in_range(start, end, user_id)
#         return jsonify(rows), 200
#
#     except Exception as e:
#         logger.exception("results_range failed")
#         # ❗ 반드시 JSON으로 응답해서 클라이언트가 '연결 끊김'을 겪지 않도록 함
#         return jsonify({"ok": False, "error": f"internal error: {str(e)}"}), 500

# === 주간 리포트 + GPT 피드백 ===
# @app.get("/report/weekly")
# def report_weekly():
#     try:
#         start = request.args.get("start")
#         end = request.args.get("end")
#         user_id = request.args.get("user_id") or None
#
#         if not start or not end:
#             return jsonify({"ok": False, "error": "start/end required"}), 400
#
#         rows = get_results_in_range(start, end, user_id)
#         if not rows:
#             return jsonify({"ok": False, "error": "no data in range"}), 404
#
#         joy=sad=ang=sur=neu=0.0; n=0
#         for e in rows:
#             emo = e.get("emotion")
#             dist = None
#             if isinstance(emo, dict):
#                 if (emo.get("fused") or {}).get("distribution"):
#                     dist = emo["fused"]["distribution"]
#                 elif (emo.get("face") or {}).get("distribution"):
#                     dist = emo["face"]["distribution"]
#                 elif (emo.get("text") or {}).get("distribution"):
#                     dist = emo["text"]["distribution"]
#             elif isinstance(emo, str):
#                 # MySQL JSON 직렬화 대비
#                 try:
#                     import json
#                     emo_obj = json.loads(emo)
#                     if (emo_obj.get("fused") or {}).get("distribution"):
#                         dist = emo_obj["fused"]["distribution"]
#                     elif (emo_obj.get("face") or {}).get("distribution"):
#                         dist = emo_obj["face"]["distribution"]
#                     elif (emo_obj.get("text") or {}).get("distribution"):
#                         dist = emo_obj["text"]["distribution"]
#                 except Exception:
#                     dist = None
#             if not dist: continue
#             joy += float(dist.get("joy", 0.0)) * 100.0
#             sad += float(dist.get("sad", 0.0)) * 100.0
#             ang += float(dist.get("anger", 0.0)) * 100.0
#             neu += float(dist.get("neutral", 0.0)) * 100.0
#             sur += float(dist.get("surprise", 0.0)) * 100.0
#             n += 1
#
#         if n == 0:
#             return jsonify({"ok": False, "error": "no usable rows"}), 404
#
#         avg_pct = {
#             "joy":      joy/n/100.0,
#             "sad":      sad/n/100.0,
#             "anger":    ang/n/100.0,
#             "surprise": sur/n/100.0,
#             "neutral":  neu/n/100.0,
#         }
#
#         try:
#             fb = gpt.make_weekly_feedback(start, end, avg_pct, sample_count=n)
#         except Exception:
#             fb = None
#
#         return jsonify({
#             "ok": True,
#             "range": {"start": start, "end": end, "count": n},
#             "avg_distribution": avg_pct,
#             "gpt_feedback": fb or "",
#         }), 200
#     except Exception as e:
#         logger.exception("report_weekly failed")
#         return jsonify({"ok": False, "error": f"internal error: {str(e)}"}), 500

