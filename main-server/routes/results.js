import express from "express";
import pool from "../db.js";
import axios from "axios";

const router = express.Router();

/* =====================================================
   ✅ 깊은 JSON 파서 (이중 인코딩 대응)
===================================================== */
function deepParse(raw) {
  try {
    let parsed = raw;
    while (typeof parsed === "string") parsed = JSON.parse(parsed);
    return parsed;
  } catch {
    return raw;
  }
}

/* =====================================================
   ✅ /day (오늘 감정 + GPT2 음악 병합 조회)
===================================================== */
router.get("/day", async (req, res) => {
  try {
    const { user_id, date } = req.query;
    if (!user_id)
      return res.status(400).json({ ok: false, message: "user_id 필요" });

    const now = new Date();
    const koreaTime = new Date(now.getTime() + 9 * 60 * 60 * 1000);
    const targetDate =
      !date || date === "undefined" || date.trim() === ""
        ? koreaTime.toISOString().split("T")[0]
        : date;

    console.log("🧩 /results/day called:", { user_id, targetDate });

    /* 🎭 감정 분석 결과 조회 */
    const [rows] = await pool.query(
      `
      SELECT id, user_id, created_at, emotion, emotion_detail, feedback, actions
      FROM analysis_results
      WHERE user_id = ?
        AND DATE(created_at) = DATE(?)
      ORDER BY created_at DESC
      LIMIT 1
      `,
      [user_id, targetDate]
    );

    if (!rows || rows.length === 0) {
      console.log("❌ 오늘 감정 데이터 없음");
      return res.json({ ok: false, message: "해당 날짜 데이터 없음" });
    }

    const latest = rows[0];
    const emoRaw = deepParse(latest.emotion_detail || latest.emotion || {});
    const dist =
      emoRaw?.fused?.distribution ||
      emoRaw?.distribution ||
      emoRaw?.text?.distribution ||
      emoRaw?.face?.distribution ||
      {};

    /* ✅ actions 복원 */
    let actions = [];
    if (latest.actions) {
      const raw = latest.actions.trim();
      if (raw.includes("\n")) actions = raw.split("\n").map((s) => s.trim());
      else if (raw.includes(",")) actions = raw.split(",").map((s) => s.trim());
      else actions = [raw];
    }

    /* 🎵 GPT2 음악 추천 최신 데이터 조회 */
    let musicList = [];
    try {
      const [mrows] = await pool.query(
        `
        SELECT music_list
        FROM analysis_results_gpt2
        WHERE user_id = ?
        ORDER BY created_at DESC
        LIMIT 1
        `,
        [user_id]
      );

      if (mrows.length > 0 && mrows[0].music_list) {
        const raw = mrows[0].music_list;
        // ✅ 확실한 JSON 파싱 로직
        if (typeof raw === "string") {
          try {
            musicList = JSON.parse(raw);
          } catch {
            musicList = deepParse(raw);
          }
        } else {
          musicList = deepParse(raw);
        }
        if (!Array.isArray(musicList)) {
          console.log("⚠️ music_list가 배열이 아님, 강제 변환 시도");
          musicList = [musicList];
        }
        console.log(`✅ GPT2 음악 ${musicList.length}곡 로드 완료`);
      } else {
        console.log("⚠️ GPT2 음악 데이터 없음");
      }
    } catch (err) {
      console.error("⚠️ gpt2 음악 불러오기 실패:", err.message);
    }

    /* ✅ 최종 응답 */
    res.json({
      ok: true,
      avg_distribution: {
        joy: dist.joy || 0,
        sad: dist.sad || 0,
        anger: dist.anger || 0,
        neutral: dist.neutral || 0,
        surprise: dist.surprise || 0,
      },
      latest_feedback: latest.feedback || "",
      actions,
      music: Array.isArray(musicList) ? musicList : [],
    });
  } catch (err) {
    console.error("❌ /results/day 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

/* =====================================================
   ✅ /range (캘린더용)
===================================================== */
router.get("/range", async (req, res) => {
  try {
    const { start, end, user_id } = req.query;
    if (!start || !end || !user_id)
      return res.status(400).json({ ok: false, message: "start, end, user_id 필요" });

    const [rows] = await pool.query(
      `
      SELECT emotion_detail, emotion, created_at
      FROM analysis_results
      WHERE user_id = ?
        AND DATE(CONVERT_TZ(created_at, '+00:00', '+09:00'))
            BETWEEN DATE(?) AND DATE(?)
      ORDER BY created_at ASC
      `,
      [user_id, start, end]
    );

    if (rows.length === 0)
      return res.json({ ok: false, message: "해당 기간 데이터 없음" });

    const result = rows.map((r) => {
      const emoRaw = deepParse(r.emotion_detail || r.emotion || {});
      const dist =
        emoRaw?.fused?.distribution ||
        emoRaw?.distribution ||
        emoRaw?.text?.distribution ||
        emoRaw?.face?.distribution ||
        {};
      return { emotion: dist, created_at: r.created_at };
    });

    res.json(result);
  } catch (err) {
    console.error("❌ /results/range 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

/* =====================================================
   ✅ /report/weekly (Flask 연동)
===================================================== */
router.get("/report/weekly", async (req, res) => {
  try {
    const { start, end, user_id } = req.query;
    if (!start || !end || !user_id)
      return res.status(400).json({ ok: false, message: "start, end, user_id 필요" });

    const flaskUrl = "http://127.0.0.1:5001/report/weekly";
    console.log("📡 Flask 주간 리포트 요청:", flaskUrl, { start, end, user_id });

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
