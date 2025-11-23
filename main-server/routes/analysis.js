import express from "express";
import axios from "axios";
import dotenv from "dotenv";
import pool from "../db.js";

dotenv.config();
const router = express.Router();

// Flask 분석 엔드포인트
const FLASK_URL = process.env.FLASK_URL || "http://10.123.108.187:5001/analyze";

  // Flask 응답 파서
function extractAnalysis(flaskData) {
  const result = flaskData?.result || {};

  // 행동 추천
  let rawActions = result.actions || [];
  let actions = [];
  if (Array.isArray(rawActions)) actions = rawActions;
  else if (typeof rawActions === "string")
    actions = rawActions.split("\n").map((s) => s.trim()).filter(Boolean);

  // 감정 분포
  const dist =
    result.fused?.distribution ||
    result.distribution ||
    result.face?.distribution ||
    result.text?.distribution ||
    flaskData?.distribution || {
      joy: 0,
      sad: 0,
      anger: 0,
      neutral: 0,
      surprise: 0,
    };

  // 감정 라벨
  const label =
    result.fused?.final_label ||
    result.final_label ||
    flaskData.final_label ||
    "unknown";

  // 피드백
  const feedback = result.feedback || flaskData.feedback || "";

  // 음악
  const music = result.music || flaskData.music || [];

  return { label, dist, feedback, actions, music };
}

  // 업로드/분석 → Flask 호출 → DB 저장
router.post(["/upload", "/file", "/analyze"], async (req, res) => {
  try {
    const { user_id, media_id, s3Key } = req.body || {};
    if (!user_id) return res.status(400).json({ ok: false, message: "user_id 필요" });
    if (!s3Key) return res.status(400).json({ ok: false, message: "s3Key 필요" });

    const flaskRes = await axios.post(FLASK_URL, {
      user_id,
      media_id,
      s3_key: s3Key,
      bucket: process.env.AWS_S3_BUCKET,
    });

    const parsed = extractAnalysis(flaskRes.data);

    if (parsed.label === "unknown" || parsed.label === "uncertain") {
      const top = Object.entries(parsed.dist).sort((a, b) => b[1] - a[1])[0];
      if (top) parsed.label = top[0];
    }

    const conn = await pool.getConnection();

    await conn.query(
      `
      INSERT INTO analysis_results
      (user_id, type, file_name, s3_key, emotion_detail, emotion, feedback, actions, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
      `,
      [
        user_id,
        "video",
        s3Key,
        s3Key,
        JSON.stringify(flaskRes.data.result || {}),
        JSON.stringify(parsed.dist),
        parsed.feedback || "",
        Array.isArray(parsed.actions) ? parsed.actions.join("\n") : "",
      ]
    );

    if (Array.isArray(parsed.music) && parsed.music.length > 0) {
      await conn.query(
        `
        INSERT INTO analysis_results_gpt2
        (user_id, music_list, created_at)
        VALUES (?, ?, NOW())
        `,
        [user_id, JSON.stringify(parsed.music)]
      );
    }

    conn.release();

    return res.json({
      ok: true,
      result: {
        emotionData: parsed.dist,
        mainEmotion: parsed.label,
        feedback: parsed.feedback,
        actions: parsed.actions,
        music: parsed.music,
      },
    });
  } catch (err) {
    console.error("❌ 분석 실패:", err.message);
    return res.status(500).json({ ok: false, error: err.message });
  }
});

function deepParse(raw) {
  try {
    let parsed = raw;
    while (typeof parsed === "string") parsed = JSON.parse(parsed);
    return parsed;
  } catch {
    return raw;
  }
}

  // 해당 날짜 최신 감정 1개
router.get("/day", async (req, res) => {
  try {
    const { user_id, date } = req.query;
    if (!user_id)
      return res.status(400).json({ ok: false, message: "user_id 필요" });

    const today = new Date();
    const target =
      !date || date === "undefined" ? today.toISOString().split("T")[0] : date;

    const [rows] = await pool.query(
      `
      SELECT id, user_id, created_at, emotion, emotion_detail, feedback, actions
      FROM analysis_results
      WHERE user_id = ?
        AND DATE(created_at) = DATE(?)
      ORDER BY created_at DESC
      LIMIT 1
      `,
      [user_id, target]
    );

    if (!rows.length)
      return res.json({ ok: false, message: "해당 날짜 데이터 없음" });

    const last = rows[0];
    const emoRaw = deepParse(last.emotion_detail || last.emotion || {});
    const dist =
      emoRaw?.fused?.distribution ||
      emoRaw?.distribution ||
      emoRaw?.text?.distribution ||
      emoRaw?.face?.distribution ||
      {};

    // 액션
    let actions = [];
    if (last.actions) {
      const raw = last.actions.trim();
      if (raw.includes("\n")) actions = raw.split("\n").map((s) => s.trim());
      else actions = [raw];
    }

    // 음악
    let musicList = [];
    const [mrows] = await pool.query(
      `
      SELECT music_list FROM analysis_results_gpt2
      WHERE user_id = ?
      ORDER BY created_at DESC
      LIMIT 1
      `,
      [user_id]
    );
    if (mrows.length && mrows[0].music_list)
      musicList = deepParse(mrows[0].music_list);

    return res.json({
      ok: true,
      avg_distribution: dist,
      feedback: last.feedback || "",
      actions,
      music: musicList,
    });
  } catch (err) {
    console.error("❌ /day 오류:", err.message);
    return res.status(500).json({ ok: false, error: err.message });
  }
});

  // 날짜별 최신 데이터 리스트
router.get("/range", async (req, res) => {
  try {
    const { start, end, user_id } = req.query;
    if (!start || !end || !user_id)
      return res.status(400).json({ ok: false, message: "start, end, user_id 필요" });

    const [rows] = await pool.query(
      `
      SELECT r1.*
      FROM analysis_results r1
      INNER JOIN (
          SELECT DATE(created_at) AS day, MAX(created_at) AS latest_time
          FROM analysis_results
          WHERE user_id = ?
            AND DATE(created_at) BETWEEN DATE(?) AND DATE(?)
          GROUP BY day
      ) r2
      ON DATE(r1.created_at) = r2.day
         AND r1.created_at = r2.latest_time
      WHERE r1.user_id = ?
      ORDER BY r1.created_at ASC
      `,
      [user_id, start, end, user_id]
    );

    const list = rows.map((r) => {
      let detail = {};
      try {
        detail =
          typeof r.emotion_detail === "string"
            ? JSON.parse(r.emotion_detail)
            : r.emotion_detail || {};
      } catch {
        detail = {};
      }

      return {
        id: r.id,
        user_id: r.user_id,
        created_at: r.created_at,
        emotion_detail: {
          fused: {
            final_label:
              detail?.fused?.final_label ||
              detail?.fused?.label ||
              detail?.label ||
              "unknown",
            distribution:
              detail?.fused?.distribution ||
              detail?.face?.distribution ||
              detail?.text?.distribution ||
              {},
          },
        },
      };
    });

    res.json(list);
  } catch (err) {
    console.error("❌ /range 오류:", err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

  // Flask 주간 GPT 리포트
router.get("/report/weekly", async (req, res) => {
  try {
    const { start, end, user_id } = req.query;
    if (!start || !end || !user_id)
      return res.status(400).json({ ok: false, message: "start, end, user_id 필요" });

    const flaskUrl = "http://10.123.108.187:5001/report/weekly";
    const flaskRes = await axios.get(flaskUrl, { params: { start, end, user_id } });

    const data = flaskRes.data || {};
    const inner = data.result || data;

    const distKo = inner.avg_distribution || {};
    const distEn = {
      joy: distKo["기쁨"] || 0,
      sad: distKo["슬픔"] || 0,
      anger: distKo["분노"] || 0,
      neutral: distKo["평온"] || 0,
      surprise: distKo["놀람"] || 0,
    };

    res.json({
      ok: true,
      count: inner.count || 0,
      avg_distribution: distEn,
      gpt_feedback: inner.gpt_feedback || "",
    });
  } catch (err) {
    console.error("❌ /report/weekly 오류:", err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});



export default router;
