// routes/results.js
import express from "express";
import pool from "../db.js";
import axios from "axios";

const router = express.Router();

/* =====================================================
   🔸 JSON 안전 파서
===================================================== */
function safeParseEmotion(raw) {
  if (!raw) return {};
  try {
    if (typeof raw === "string") return JSON.parse(raw);
    return raw;
  } catch {
    return {};
  }
}

/* =====================================================
   1️⃣ /results/day  (단일 날짜 감정 평균)
===================================================== */
router.get("/results/day", async (req, res) => {
  try {
    const { date, user_id } = req.query;
    if (!date || !user_id)
      return res.status(400).json({ ok: false, message: "date 또는 user_id 누락" });

    const [rows] = await pool.query(
      `
      SELECT emotion_detail, emotion, feedback, created_at
      FROM analysis_results
      WHERE user_id=? AND DATE(created_at)=?
      ORDER BY created_at ASC
      `,
      [user_id, date]
    );

    if (rows.length === 0)
      return res.status(404).json({ ok: false, message: "결과 없음", data: [] });

    const keys = ["joy", "sad", "anger", "neutral", "surprise"];
    const avg = Object.fromEntries(keys.map((k) => [k, 0]));
    let feedback = "";

    for (const r of rows) {
      let emo =
        Object.keys(safeParseEmotion(r.emotion_detail)).length > 0
          ? safeParseEmotion(r.emotion_detail)
          : safeParseEmotion(r.emotion);

      let dist = {};
      if (emo?.fused?.distribution) dist = emo.fused.distribution;
      else if (emo?.distribution) dist = emo.distribution;
      else if (emo?.fused) dist = emo.fused;
      else if (emo) dist = emo;

      for (const k of keys) {
        if (typeof dist[k] === "number") avg[k] += dist[k];
      }

      if (r.feedback && !feedback) feedback = r.feedback;
    }

    keys.forEach((k) => (avg[k] = +(avg[k] / rows.length).toFixed(4)));

    res.json({
      ok: true,
      total: rows.length,
      avg_distribution: avg,
      latest_feedback: feedback,
    });
  } catch (err) {
    console.error("❌ /results/day 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

/* =====================================================
   2️⃣ /results/range  (캘린더용)
===================================================== */
router.get("/results/range", async (req, res) => {
  try {
    const { start, end, user_id } = req.query;
    if (!start || !end || !user_id)
      return res.status(400).json({ ok: false, message: "start, end, user_id 필요" });

    const [rows] = await pool.query(
      `
      SELECT emotion_detail, emotion, created_at
      FROM analysis_results
      WHERE user_id=? AND DATE(created_at) BETWEEN ? AND ?
      ORDER BY created_at ASC
      `,
      [user_id, start, end]
    );

    if (rows.length === 0)
      return res.status(404).json({ ok: false, message: "해당 기간 데이터 없음" });

    const list = rows.map((r) => {
      let emo =
        Object.keys(safeParseEmotion(r.emotion_detail)).length > 0
          ? safeParseEmotion(r.emotion_detail)
          : safeParseEmotion(r.emotion);

      let dist = {};
      if (emo?.fused?.distribution) dist = emo.fused.distribution;
      else if (emo?.distribution) dist = emo.distribution;
      else if (emo?.fused) dist = emo.fused;
      else if (emo) dist = emo;

      return {
        emotion: dist,
        created_at: r.created_at,
      };
    });

    res.json(list);
  } catch (err) {
    console.error("❌ /results/range 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

/* =====================================================
   3️⃣ /report/weekly (Flask 주간 리포트 연동)
===================================================== */
router.get("/report/weekly", async (req, res) => {
  try {
    const { start, end, user_id } = req.query;
    if (!start || !end || !user_id)
      return res.status(400).json({ ok: false, message: "start, end, user_id 필요" });

    const flaskUrl =
      process.env.FLASK_WEEKLY_URL || "http://127.0.0.1:5001/report/weekly";

    const response = await axios.get(flaskUrl, {
      params: { start, end, user_id },
    });

    const data = response.data || {};
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

export default router;
