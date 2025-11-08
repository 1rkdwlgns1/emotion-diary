// routes/analysis.js
import express from "express";
import axios from "axios";
import dotenv from "dotenv";
import pool from "../db.js";

dotenv.config();
const router = express.Router();
const FLASK_URL = process.env.FLASK_URL || "http://127.0.0.1:5001/analyze";

/* =======================================================
   📦 Flask 응답 파서
======================================================= */
function extractAnalysis(flaskData) {
  const result = flaskData?.result || {};
  const fused = result.fused || {};
  const text = result.text || {};
  const face = result.face || {};
  const music = result.music || [];

  return {
    label: fused.final_label || result.final_label || "unknown",
    dist:
      fused.distribution ||
      face.distribution ||
      text.distribution || {
        joy: 0,
        sad: 0,
        anger: 0,
        neutral: 0,
        surprise: 0,
      },
    confidence: fused.confidence || 0.0,
    transcript: text.transcript || result.transcript || "",
    feedback:
      result.feedback ||
      flaskData.feedback ||
      "감정 분석 결과를 가져올 수 없습니다.",
    music,
  };
}

/* =======================================================
   1️⃣ /upload, /file, /analyze — Flask 분석 + DB 저장
======================================================= */
router.post(["/upload", "/file", "/analyze"], async (req, res) => {
  try {
    const { user_id, media_id, s3Key } = req.body || {};
    let s3_key = s3Key;

    if (!user_id) {
      return res.status(400).json({ ok: false, message: "user_id 누락됨" });
    }

    // 🔹 media_id 기준으로 s3_key 조회 (없을 때)
    if (!s3_key && media_id) {
      const [rows] = await pool.query(
        "SELECT s3_key FROM media WHERE media_id = ?",
        [media_id]
      );
      if (rows.length > 0) s3_key = rows[0].s3_key;
    }
    if (!s3_key) {
      return res.status(400).json({ ok: false, message: "s3Key 누락됨" });
    }

    // 🔹 Flask 분석 요청
    console.log("📡 Flask 요청 전송:", FLASK_URL, { user_id, s3_key });
    const flaskRes = await axios.post(FLASK_URL, {
      s3_key,
      bucket: process.env.AWS_S3_BUCKET,
      user_id,
      media_id,
    });

    // 🔹 Flask 응답 파싱
    const parsed = extractAnalysis(flaskRes.data);

    // 🔹 감정 데이터 구성
    const emotionData = {
      joy: (parsed.dist.joy || 0) * 100,
      sad: (parsed.dist.sad || 0) * 100,
      anger: (parsed.dist.anger || 0) * 100,
      neutral: (parsed.dist.neutral || 0) * 100,
      surprise: (parsed.dist.surprise || 0) * 100,
    };

    const sorted = Object.entries(parsed.dist || {}).sort((a, b) => b[1] - a[1]);
    const topKey = sorted[0]?.[0] || "neutral";

    const emotionMap = {
      joy: "기쁨",
      sad: "슬픔",
      anger: "분노",
      neutral: "평온",
      surprise: "놀람",
    };

    /* =====================================================
       ✅ Flask 분석 결과를 MySQL에 저장
    ===================================================== */
    try {
      const conn = await pool.getConnection();
      await conn.query(
        `
        INSERT INTO analysis_results
        (user_id, type, file_name, s3_key, emotion_detail, emotion, feedback, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, NOW())

        `,
        [
          user_id || "anon",
          "video",
          s3_key || "",
          s3_key || "",
          JSON.stringify(flaskRes.data.result || {}),
          JSON.stringify(flaskRes.data.result || {}),
          parsed.feedback || "",
        ]
      );
      conn.release();
      console.log("✅ Flask 분석 결과 DB 저장 완료");
    } catch (dbErr) {
      console.error("❌ DB 저장 실패:", dbErr);
    }

    /* =====================================================
       ✅ Flutter 응답 (UI 표시용)
    ===================================================== */
    res.json({
      ok: true,
      result_id: 0,
      feedback: parsed.feedback,
      flaskResponse: flaskRes.data,
      result: {
        emotionData,
        mainEmotion: emotionMap[topKey] || "평온",
        gptFeedback:
          parsed.feedback ||
          flaskRes.data?.result?.feedback ||
          "감정 분석 피드백이 없습니다.",
        music: flaskRes.data?.result?.music ?? [],
      },
    });
  } catch (err) {
    console.error("❌ 분석 처리 오류:", err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});
/* =======================================================
   3️⃣ /report/weekly — Flask 주간 리포트 요청 중계
======================================================= */
router.get("/report/weekly", async (req, res) => {
  try {
    const { start, end, user_id } = req.query;

    if (!start || !end || !user_id) {
      return res
        .status(400)
        .json({ ok: false, message: "start, end, user_id 누락됨" });
    }

    const flaskWeeklyUrl =
      process.env.FLASK_WEEKLY_URL || "http://127.0.0.1:5001/report/weekly";

    console.log("📡 Flask 주간 리포트 요청:", flaskWeeklyUrl, {
      start,
      end,
      user_id,
    });

    const flaskRes = await axios.get(flaskWeeklyUrl, {
      params: { start, end, user_id },
    });

    const data = flaskRes.data || {};

    // ✅ Flask 응답 구조 그대로 매핑
    const distKo = data?.avg_distribution || {};
    const distEn = {
      joy: distKo["기쁨"] || 0,
      sad: distKo["슬픔"] || 0,
      anger: distKo["분노"] || 0,
      neutral: distKo["평온"] || 0,
      surprise: distKo["놀람"] || 0,
    };

    res.json({
      ok: true,
      count: data.count || 0,
      avg_distribution: distEn,
      gpt_feedback: data.gpt_feedback || "",
    });
  } catch (err) {
    console.error("❌ /report/weekly 오류:", err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});


/* =======================================================
   2️⃣ /health — Flask 연결 상태 확인용
======================================================= */
router.get("/health", async (req, res) => {
  try {
    const flaskUrl = process.env.FLASK_HEALTH || "http://127.0.0.1:5001/health";
    const { data } = await axios.get(flaskUrl);
    res.json({ ok: true, flask: data });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});
/* =======================================================
   ✅ 감정 결과 범위 조회 (/results/range)
   Flutter 주간 그래프에서 사용하는 API
======================================================= */
/* =======================================================
   ✅ 감정 결과 범위 조회 (/results/range)
   Flutter 주간 그래프에서 사용하는 API
======================================================= */
router.get("/results/range", async (req, res) => {
  try {
    const { start, end, user_id } = req.query;
    if (!start || !end || !user_id) {
      return res
        .status(400)
        .json({ ok: false, message: "start, end, user_id 필요" });
    }

    // ✅ 날짜 비교 시 DATE()로만 비교 (시간 제거)
    const [rows] = await pool.query(
      `
      SELECT emotion_detail, emotion, created_at
      FROM analysis_results
      WHERE user_id = ?
        AND DATE(created_at) BETWEEN DATE(?) AND DATE(?)
      ORDER BY created_at ASC
      `,
      [user_id, start, end]
    );

    if (rows.length === 0)
      return res.json({ ok: false, message: "해당 기간 데이터 없음" });

    const result = rows.map((r) => {
      let emoRaw = r.emotion_detail || r.emotion;
      if (!emoRaw) return null;

      // ✅ JSON 2중 파싱 보정
      if (typeof emoRaw === "string") {
        try {
          emoRaw = JSON.parse(emoRaw);
          if (typeof emoRaw === "string") emoRaw = JSON.parse(emoRaw);
        } catch {
          emoRaw = {};
        }
      }

      const dist =
        emoRaw?.fused?.distribution ||
        emoRaw?.distribution ||
        emoRaw?.text?.distribution ||
        emoRaw?.face?.distribution ||
        {};

      return {
        emotion: dist,
        created_at: r.created_at,
      };
    }).filter(Boolean);

    res.json(result);
  } catch (err) {
    console.error("❌ /results/range 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

export default router;
