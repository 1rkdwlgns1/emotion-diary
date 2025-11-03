// routes/results.js
import express from "express";
import pool from "../db.js";
import axios from "axios";

const router = express.Router();

/* =====================================================
   1️⃣  /analysis/results/day
   특정 날짜 감정결과 평균 + 최신 피드백 조회
===================================================== */
router.get("/day", async (req, res) => {
  try {
    const { date, user_id } = req.query;
    if (!date || !user_id) {
      return res.status(400).json({ ok: false, message: "date 또는 user_id 누락" });
    }

    const [rows] = await pool.query(
      `SELECT top_emotion, emotion_detail, feedback, created_at
       FROM emotion_result
       WHERE user_id=? AND DATE(created_at)=?
       ORDER BY created_at ASC`,
      [user_id, date]
    );

    if (rows.length === 0) {
      return res.status(404).json({ ok: false, message: "해당 날짜의 결과 없음" });
    }

    const keys = ["joy", "sad", "anger", "neutral", "surprise"];
    const avg = Object.fromEntries(keys.map(k => [k, 0]));
    for (const r of rows) {
      const dist = JSON.parse(r.emotion_detail || "{}");
      keys.forEach(k => {
        if (typeof dist[k] === "number") avg[k] += dist[k];
      });
    }
    keys.forEach(k => (avg[k] = avg[k] / rows.length));

    res.json({
      ok: true,
      total: rows.length,
      avg_distribution: avg,
      latest_top_emotion: rows[rows.length - 1].top_emotion,
      latest_feedback: rows[rows.length - 1].feedback || "",
    });
  } catch (err) {
    console.error("❌ /analysis/results/day 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

/* =====================================================
   2️⃣  /analysis/results/range
   기간 평균 (캘린더 리포트용)
===================================================== */
router.get("/range", async (req, res) => {
  try {
    const { start_date, end_date, user_id } = req.query;
    if (!start_date || !end_date || !user_id) {
      return res.status(400).json({ ok: false, message: "start_date, end_date, user_id 필요" });
    }

    const [rows] = await pool.query(
      `SELECT emotion_detail FROM emotion_result
       WHERE user_id=? AND DATE(created_at) BETWEEN ? AND ?`,
      [user_id, start_date, end_date]
    );
    if (rows.length === 0) {
      return res.status(404).json({ ok: false, message: "해당 기간 데이터 없음" });
    }

    const keys = ["joy", "sad", "anger", "neutral", "surprise"];
    const avg = Object.fromEntries(keys.map(k => [k, 0]));
    for (const r of rows) {
      const dist = JSON.parse(r.emotion_detail || "{}");
      keys.forEach(k => {
        if (typeof dist[k] === "number") avg[k] += dist[k];
      });
    }
    keys.forEach(k => (avg[k] = avg[k] / rows.length));

    res.json({
      ok: true,
      count: rows.length,
      avg_distribution: avg,
    });
  } catch (err) {
    console.error("❌ /analysis/results/range 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

/* =====================================================
   3️⃣  /analysis/report/weekly (선택)
   Flask 주간 GPT 요약 요청
===================================================== */
router.get("/report/weekly", async (req, res) => {
  try {
    const { start_date, end_date, user_id } = req.query;
    if (!start_date || !end_date || !user_id) {
      return res.status(400).json({ ok: false, message: "start_date, end_date, user_id 필요" });
    }

    const flaskUrl =
      process.env.FLASK_WEEKLY_URL ||
      "http://127.0.0.1:5001/report/weekly";

    const response = await axios.get(flaskUrl, {
      params: { start: start_date, end: end_date, user_id },
    });

    res.json(response.data);
  } catch (err) {
    console.error("❌ /analysis/report/weekly 오류:", err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

export default router;
