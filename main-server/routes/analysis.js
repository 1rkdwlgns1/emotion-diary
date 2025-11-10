// routes/analysis.js
import express from "express";
import axios from "axios";
import dotenv from "dotenv";
import pool from "../db.js";

dotenv.config();
const router = express.Router();
const FLASK_URL = process.env.FLASK_URL || "http://127.0.0.1:5001/analyze";

/* =======================================================
   📦 Flask 응답 파서 (정상/결측 대응)
======================================================= */
function extractAnalysis(flaskData) {
  const base = flaskData?.result || flaskData || {};
  const fused = base.fused || flaskData.fused || {};
  const text = base.text || flaskData.text || {};
  const face = base.face || flaskData.face || {};
  const music =
    base.music ||
    flaskData.music ||
    flaskData.result?.music ||
    flaskData.result?.result?.music ||
    [];

  return {
    label:
      fused.final_label ||
      base.final_label ||
      flaskData.final_label ||
      "unknown",
    dist:
      fused.distribution ||
      face.distribution ||
      text.distribution ||
      base.distribution || {
        joy: 0,
        sad: 0,
        anger: 0,
        neutral: 0,
        surprise: 0,
      },
    confidence:
      fused.confidence || base.confidence || flaskData.confidence || 0.0,
    transcript:
      text.transcript ||
      base.transcript ||
      flaskData.text?.transcript ||
      "",
    feedback:
      base.feedback ||
      flaskData.feedback ||
      "감정 분석 결과를 가져올 수 없습니다.",
    actions:
      base.actions ||
      flaskData.actions ||
      flaskData.result?.actions ||
      flaskData.result?.result?.actions ||
      [],
    music,
  };
}

/* =======================================================
   1️⃣ /upload, /file, /analyze — Flask 분석 + DB 분리 저장
======================================================= */
router.post(["/upload", "/file", "/analyze"], async (req, res) => {
  try {
    const { user_id, media_id, s3Key } = req.body || {};
    let s3_key = s3Key;

    if (!user_id)
      return res.status(400).json({ ok: false, message: "user_id 누락됨" });

    if (!s3_key && media_id) {
      const [rows] = await pool.query(
        "SELECT s3_key FROM media WHERE media_id = ?",
        [media_id]
      );
      if (rows.length > 0) s3_key = rows[0].s3_key;
    }

    if (!s3_key)
      return res.status(400).json({ ok: false, message: "s3Key 누락됨" });

    console.log("📡 Flask 요청 전송:", FLASK_URL, { user_id, s3_key });

    const flaskRes = await axios.post(FLASK_URL, {
      s3_key,
      bucket: process.env.AWS_S3_BUCKET,
      user_id,
      media_id,
    });

    const parsed = extractAnalysis(flaskRes.data);
    const actions =
      flaskRes.data?.result?.actions ??
      flaskRes.data?.actions ??
      parsed.actions ??
      [];

    // ✅ actions TEXT 변환
    const actionsText = Array.isArray(actions)
      ? actions.join("\n")
      : typeof actions === "string"
      ? actions
      : "";

    // ✅ music 데이터 (중첩 대응)
    const musicArr =
      parsed.music ||
      flaskRes.data.result?.music ||
      flaskRes.data.result?.result?.music ||
      [];

    console.log("🎵 최종 musicArr:", musicArr);

    const conn = await pool.getConnection();

    /* ------------------ 🎭 감정 분석 결과 저장 ------------------ */
    await conn.query(
      `
      INSERT INTO analysis_results
      (user_id, type, file_name, s3_key, emotion_detail, emotion, feedback, actions, music_list, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
      `,
      [
        user_id || "anon",
        "video",
        s3_key || "",
        s3_key || "",
        JSON.stringify(flaskRes.data.result || {}),
        JSON.stringify(parsed.dist || {}),
        parsed.feedback || "",
        actionsText,
        "[]", // 감정 테이블에는 음악 미포함
      ]
    );

    /* ------------------ 🎵 음악 추천 결과 별도 저장 ------------------ */
    if (Array.isArray(musicArr) && musicArr.length > 0) {
      await conn.query(
        `
        INSERT INTO analysis_results_gpt2
        (user_id, music_list, created_at)
        VALUES (?, ?, NOW())
        `,
        [user_id || "anon", JSON.stringify(musicArr)]
      );
      console.log("🎵 GPT2 음악 추천 저장 완료 (analysis_results_gpt2)");
    } else {
      console.log("⚠️ GPT2 음악 결과 없음, 저장 생략");
    }

    conn.release();
    console.log("✅ Flask 분석 결과 DB 저장 완료 (감정 + 음악 분리)");

    const sorted = Object.entries(parsed.dist || {}).sort(
      (a, b) => b[1] - a[1]
    );
    const topKey = sorted[0]?.[0] || "neutral";
    const emotionMap = {
      joy: "기쁨",
      sad: "슬픔",
      anger: "분노",
      neutral: "평온",
      surprise: "놀람",
    };

    // ✅ Flutter로 최종 응답 반환 (music을 최상위에도 추가)
    res.json({
      ok: true,
      result_id: 0,
      feedback: parsed.feedback,
      music: musicArr, // 🎵 Flutter가 직접 인식 가능하도록 최상위에 추가
      flaskResponse: flaskRes.data,
      result: {
        emotionData: parsed.dist,
        mainEmotion: emotionMap[topKey] || "평온",
        gptFeedback: parsed.feedback,
        actions,
        music: musicArr,
      },
    });
  } catch (err) {
    console.error("❌ 분석 처리 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

export default router;
