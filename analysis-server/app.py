# app.py

import os
from uuid import uuid4

from flask import Flask, request, jsonify
from flask_cors import CORS

import services
from config import UPLOAD_DIR, ALLOWED_AUDIO, ALLOWED_IMAGE

app = Flask(__name__)
CORS(app)

# 업로드 폴더 보장
os.makedirs(UPLOAD_DIR, exist_ok=True)


@app.route("/", methods=["GET"])
def root():
    return "Analysis Server is running!"


@app.route("/analyze/text", methods=["POST"])
def analyze_text():
    data = request.get_json(silent=True) or {}
    text = (data.get("text") or "").strip()
    nlp_result = services.nlp.analyze(text)
    return jsonify({
        "type": "text",
        "text": text,
        "text_emotion": nlp_result,
    }), 200


@app.route("/analyze/file", methods=["POST"])
def analyze_file():
    """
    form-data 로 file 업로드:
      - 이미지(.jpg/.jpeg/.png 등) → Face 감정(services.vision.analyze)
      - 오디오(.wav/.mp3/.m4a)     → Whisper STT → NLP 감정
      - 비디오는 TODO (ffmpeg 추출 후 STT)
    """

    # ✅ 여기 print 추가해서 서버 콘솔에 확인
    print("FILES:", list(request.files.keys()))
    if "file" in request.files:
        print("RAW NAME:", request.files["file"].filename)

    if "file" not in request.files:
        return jsonify({"ok": False, "error": "file field is required"}), 400

    f = request.files["file"]
    orig_name = (f.filename or "").strip()
    if not orig_name:
        return jsonify({"ok": False, "error": "empty filename"}), 400

    # 1) 원본 파일명에서 확장자 추출 (한글 파일명 대응)
    _, ext = os.path.splitext(orig_name)
    ext = ext.lower()

    # 2) 허용 확장자 판별
    if ext in ALLOWED_IMAGE:
        kind = "image"
    elif ext in ALLOWED_AUDIO:
        kind = "audio"
    elif ext in {".mp4", ".mov", ".avi", ".mkv"}:
        kind = "video"
    else:
        return jsonify({"ok": False, "error": f"unsupported file type: {ext}"}), 415

    # 3) 저장용 안전 파일명 (UUID + 확장자)
    safe_name = f"{uuid4().hex}{ext}"
    save_path = os.path.join(UPLOAD_DIR, safe_name)
    f.save(save_path)

    # 4) 유형별 처리
    try:
        if kind == "image":
            face = services.vision.analyze(save_path)
            return jsonify({
                "ok": True,
                "type": "image",
                "file": safe_name,
                "emotion": face.get("emotion"),
                "details": {"face": face},
            }), 200

        if kind == "audio":
            text = services.stt.transcribe(save_path)
            nlp_result = services.nlp.analyze(text)
            return jsonify({
                "ok": True,
                "type": "audio",
                "file": safe_name,
                "emotion": nlp_result.get("emotion"),
                "details": {"stt_text": text, "nlp": nlp_result},
            }), 200

        # video (추후 ffmpeg 적용)
        return jsonify({
            "ok": True,
            "type": "video",
            "file": safe_name,
            "todo": "ffmpeg로 오디오 추출 후 Whisper 적용 필요",
        }), 202

    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


if __name__ == "__main__":
    # http://127.0.0.1:5001
    app.run(host="0.0.0.0", port=5001, debug=True)
