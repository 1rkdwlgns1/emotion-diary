import os, re, time, logging, hashlib, datetime, json
from uuid import uuid4
from flask import Flask, request, jsonify, Response
from flask_cors import CORS
from dotenv import load_dotenv, find_dotenv
load_dotenv(find_dotenv(), override=True)

# 서비스 모듈 
from services.db import init_db, get_results_in_range
from config import UPLOAD_DIR, ALLOWED_AUDIO, ALLOWED_IMAGE
from services import media
import services.kobert as kobert
import services.fusion as fusion
import services.stt as stt
import services.vision as vision
import services.s3uploader as s3uploader
import services.gpt as gpt        # 감정 분석용 (피드백/행동)
import services.gpt2 as gpt2      # 음악 추천용
import services.gptAI as gptAI    # 감정이 대화용


# 경로 및 환경 설정
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_CACHE_DIR = os.getenv("MODEL_CACHE_DIR", os.path.join(BASE_DIR, "models"))
os.makedirs(MODEL_CACHE_DIR, exist_ok=True)
os.environ.setdefault("HF_HOME", MODEL_CACHE_DIR)
os.environ.setdefault("TRANSFORMERS_CACHE", MODEL_CACHE_DIR)
os.environ.setdefault("TORCH_HOME", MODEL_CACHE_DIR)
os.makedirs(UPLOAD_DIR, exist_ok=True)

# 로깅 설정
LOG_DIR = os.path.join(BASE_DIR, "logs")
os.makedirs(LOG_DIR, exist_ok=True)
logger = logging.getLogger("analysis-server")
logger.setLevel(logging.INFO)
if not logger.handlers:
    fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
    fh = logging.FileHandler(os.path.join(LOG_DIR, "server.log"), encoding="utf-8")
    ch = logging.StreamHandler()
    fh.setFormatter(fmt)
    ch.setFormatter(fmt)
    logger.addHandler(fh)
    logger.addHandler(ch)

logger.info("=== Flask Analysis Server Boot ===")

# Flask 앱 설정
app = Flask(__name__)
CORS(app)
app.config["MAX_CONTENT_LENGTH"] = int(os.getenv("MAX_CONTENT_MB", "200")) * 1024 * 1024
app.config["JSON_AS_ASCII"] = False

# JSON 응답 유틸 
def _json_ok(payload, code=200):
    return Response(json.dumps(payload, ensure_ascii=False), mimetype="application/json", status=code)

def _json_err(msg, code=500):
    return _json_ok({"ok": False, "error": msg}, code)

# 기본 라우트
@app.get("/")
def root():
    return "✅ Flask Analysis Server is running."

@app.get("/health")
def health():
    ok_whisper = hasattr(stt, "_model") and (stt._model is not None)
    try:
        _ = kobert.predict("테스트")
        ok_kobert = True
    except Exception:
        ok_kobert = False
    return jsonify({
        "ok": True,
        "models": {"whisper": ok_whisper, "kobert": ok_kobert, "deepface": "ok"},
    }), 200


# 파일 분석 (Node → Flask 호출 시 사용)
@app.post("/analyze/file")
def analyze_file():
    t0 = time.time()
    if "file" not in request.files:
        return _json_err("file field is required", 400)

    f = request.files["file"]
    orig = (f.filename or "").strip()
    if not orig:
        return _json_err("empty filename", 400)
    _, ext = os.path.splitext(orig)
    ext = ext.lower()

    if ext in ALLOWED_IMAGE:
        kind = "image"
    elif ext in ALLOWED_AUDIO:
        kind = "audio"
    elif ext in {".mp4", ".mov", ".avi", ".mkv"}:
        kind = "video"
    else:
        return _json_err(f"unsupported file type: {ext}", 415)

    safe = f"{uuid4().hex}{ext}"
    path = os.path.join(UPLOAD_DIR, safe)
    f.save(path)
    logger.info(f"[UPLOAD] {orig} → {path} ({kind})")

    s3_key = None
    try:
        s3_key = s3uploader.upload_async(path, safe)
    except Exception as e:
        logger.warning(f"S3 upload warn: {e}")

    try:
        # 감정 분석 로직
        if kind == "image":
            face = vision.analyze(path) or {}
            face_dist5 = face.get("distribution") or {"joy": 0, "sad": 0, "anger": 0, "neutral": 1, "surprise": 0}
            result = {"type": "image", "face": {"distribution": face_dist5}}

        elif kind == "audio":
            pack = stt.transcribe(path)
            text = pack.get("text", "")
            segs = pack.get("segments", [])
            text_dist5 = kobert.predict_segments(segs) if segs else kobert.predict(text)
            raw7 = kobert.predict7(text)
            result = {"type": "audio", "text": {"transcript": text, "distribution": text_dist5, "raw7": raw7}}

        else:
            vpack = vision.analyze_video_weighted(path, sample_sec=0.5, max_frames=180)
            face_dist5 = vpack.get("scores5", {"joy": 0, "sad": 0, "anger": 0, "neutral": 1, "surprise": 0})
            timeline = vpack.get("timeline", [])
            transcript, segs = "", []
            if media.has_audio(path):
                wav = media.extract_wav(path, UPLOAD_DIR)
                tp = stt.transcribe(wav)
                transcript = tp.get("text", "")
                segs = tp.get("segments", [])
                text_dist5 = kobert.predict_segments(segs) if segs else kobert.predict(transcript)
                os.remove(wav)
            else:
                text_dist5 = {"joy": 0, "sad": 0, "anger": 0, "neutral": 1, "surprise": 0}

            fused = fusion.fuse(text_dist5, face_dist5, alpha=0.7, beta=0.3)
            result = {
                "type": "video",
                "text": {"transcript": transcript, "distribution": text_dist5},
                "face": {"timeline": timeline, "distribution": face_dist5},
                "fused": fused,
            }

        # GPT 피드백 + 행동 + 음악 추천
        fused_dist = result.get("fused", {}).get("distribution", {})
        transcript = result.get("text", {}).get("transcript", "")

        # 피드백 생성
        fb = gpt.make_feedback(time.strftime("%Y-%m-%d"), fused_dist, transcript)
        if fb:
            result["feedback"] = fb
            logger.info("[GPT] Feedback 생성 완료")

        # 행동 추천 생성
        try:
            acts = gpt.make_actions(fused_dist, transcript)
            if isinstance(acts, str):
                acts_list = [a.strip() for a in acts.split("\n") if a.strip()]
            elif isinstance(acts, list):
                acts_list = acts
            else:
                acts_list = []
            if acts_list:
                result["actions"] = acts_list
                logger.info(f"[GPT] Actions {len(acts_list)}개 생성 완료")
        except Exception as e:
            logger.warning(f"행동 추천 실패: {e}")

        # 음악 추천 (Node 요청 시 내부 생성용)
        try:
            top_emotion = max(fused_dist, key=fused_dist.get) if fused_dist else "neutral"
            songs = gpt2.make_music_recs(top_emotion, count=5)
            if songs:
                result["music"] = songs
                logger.info(f"[GPT2] 음악 추천 {len(songs)}곡 생성 완료 ({top_emotion})")
        except Exception as e:
            logger.warning(f"GPT2 음악 추천 실패: {e}")

        logger.info("[DB Disabled] 결과 저장 안 함 (Node 전달만)")
        return _json_ok({
            "ok": True,
            "file": safe,
            "s3_key": s3_key,
            "result": result,
            "metrics": {"elapsed_ms": int((time.time() - t0) * 1000)},
        }, 200)

    except Exception as e:
        logger.exception("analysis failed")
        return _json_err(str(e), 500)


# Node → Flask 연동용
@app.post("/analyze")
def analyze_from_s3():
    try:
        data = request.json or {}
        s3_key = data.get("s3_key") or data.get("s3Key")
        if not s3_key:
            return _json_err("s3_key 누락", 400)

        local_path = s3uploader.download(s3_key)
        if not local_path or not os.path.exists(local_path):
            return _json_err(f"파일 다운로드 실패: {s3_key}", 404)

        from werkzeug.datastructures import FileStorage
        with open(local_path, "rb") as f:
            fake_file = FileStorage(stream=f, filename=os.path.basename(local_path))
            request.files = {"file": fake_file}
            return analyze_file()
    except Exception as e:
        logger.exception("Flask /analyze 실패")
        return _json_err(str(e), 500)


# Flutter 전용 실시간 음악 추천 API
@app.post("/recommend/music")
def recommend_music():
    try:
        data = request.get_json(force=True)
        dist = data.get("distribution", {})
        if not dist:
            return _json_err("distribution 누락", 400)

        top_emotion = max(dist, key=dist.get)
        logger.info(f"[MUSIC] 🎵 감정 기반 음악 추천 요청: {top_emotion}")

        songs = gpt2.make_music_recs(top_emotion, count=5)
        if songs:
            logger.info(f"[MUSIC] 추천 {len(songs)}곡 반환됨")
        else:
            logger.warning("GPT2 음악 결과 없음 (빈 리스트)")

        return _json_ok({"ok": True, "music": songs})
    except Exception as e:
        logger.exception("/recommend/music 실패")
        return _json_err(str(e), 500)


# 주간 리포트
@app.get("/report/weekly")
def report_weekly():
    try:
        start = request.args.get("start")
        end = request.args.get("end")
        user_id = request.args.get("user_id", "anon")
        if not start or not end:
            return _json_err("start/end required", 400)

        rows = get_results_in_range(user_id, start, end)
        if not rows:
            return _json_err("no data found", 404)

        keys = ["joy", "sad", "anger", "neutral", "surprise"]
        avg = {k: 0.0 for k in keys}
        count = 0
        for r in rows:
            emo_raw = r.get("emotion_detail") or r.get("emotion")
            if not emo_raw:
                continue
            if isinstance(emo_raw, str):
                try:
                    emo = json.loads(emo_raw)
                    if isinstance(emo, str):
                        emo = json.loads(emo)
                except Exception:
                    emo = {}
            elif isinstance(emo_raw, dict):
                emo = emo_raw
            else:
                emo = {}

            dist = (
                emo.get("fused", {}).get("distribution")
                or emo.get("distribution")
                or emo.get("text", {}).get("distribution")
                or emo.get("face", {}).get("distribution")
                or {}
            )
            if not isinstance(dist, dict):
                continue
            for k in keys:
                avg[k] += float(dist.get(k, 0))
            count += 1

        if count > 0:
            for k in keys:
                avg[k] = round((avg[k] / count) * 100, 2)

        fb = gpt.make_weekly_feedback(start, end, avg, sample_count=count)
        avg_ko = {"기쁨": avg["joy"], "슬픔": avg["sad"], "분노": avg["anger"], "평온": avg["neutral"], "놀람": avg["surprise"]}

        return _json_ok({"ok": True, "count": count, "avg_distribution": avg_ko, "gpt_feedback": fb})
    except Exception as e:
        logger.exception("/report/weekly 실패")
        return _json_err(str(e), 500)


# Flutter 전용 감정이 대화 API (gptAI 전용)
@app.post("/chat")
def chat():
    """
    EmotionChatScreen에서 AI 감정 대화용 엔드포인트.
    """
    try:
        data = request.get_json(force=True)
        msg = data.get("message", "")
        emotion = data.get("emotion", "neutral")
        history = data.get("history", [])

        if not msg:
            return jsonify({"reply": "무슨 이야기 하고 싶어? 😊"})

        reply = gptAI.make_chat_reply(message=msg, history=history, emotion=emotion)
        if not reply:
            reply = "응, 그래도 괜찮아 😊"

        return jsonify({"reply": reply})

    except Exception as e:
        logger.exception("/chat 실패")
        return jsonify({"reply": "서버 오류가 발생했어요 😢"}), 500

# 주간 인사이트 생성 (GPT 코칭 문장 자동 생성)
@app.post("/report/weekly-insight")
def weekly_insight():
    """
    Node.js에서 전달하는 JSON:
    {
        "intense_date": "2025-11-12",
        "stable_date": "2025-11-14",
        "avg_dist": { ... }
    }
    """
    try:
        data = request.get_json(force=True)

        intense = data.get("intense_date")
        stable = data.get("stable_date")
        avg_dist = data.get("avg_dist", {})

        if not intense or not stable:
            return jsonify({"ok": False, "error": "intense_date, stable_date 필요"}), 400

        # 날짜 파싱
        try:
            d1 = datetime.datetime.fromisoformat(intense)
            d2 = datetime.datetime.fromisoformat(stable)
        except Exception:
            return jsonify({"ok": False, "error": "날짜 파싱 실패"}), 400

        # GPT 프롬프트 생성
        prompt = f"""
당신은 감정 전문가입니다. 아래 데이터를 기반으로 사용자의 '이번 주 핵심 인사이트'를 자연스럽고 따뜻한 말투로 작성하세요.

- 감정이 가장 흔들린 날: {d1.month}월 {d1.day}일
- 가장 안정적이었던 날: {d2.month}월 {d2.day}일
- 주간 평균 감정 분포: {json.dumps(avg_dist, ensure_ascii=False)}

규칙:
1) 총 4~5 문장
2) 첫 문단: 흔들린 날에 대한 자연스러운 코멘트
3) 두 번째 문단: 안정된 날에 대한 코멘트
4) 상담 멘트 X (힘내세요 X)
5) "~에요" 형태의 자연스러운 구어체 사용
6) 이모지는 ✨, 🌿 정도만 허용
"""

        from services.gpt import make_weekly_insight

        gpt_text = make_weekly_insight(intense, stable, avg_dist).strip()


        return jsonify({
            "ok": True,
            "insight": gpt_text,
            "intense": intense,
            "stable": stable
        })

    except Exception as e:
        print("weekly_insight 오류:", e)
        return jsonify({"ok": False, "error": str(e)}), 500
# 서버 실행
try:
    init_db()
    logger.info("DB init skipped (disabled).")
except Exception:
    logger.exception("DB init failed")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=False, threaded=True)
