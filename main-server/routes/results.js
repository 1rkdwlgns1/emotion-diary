import express from "express";
import pool from "../db.js";
import axios from "axios";

const router = express.Router();

  // JSON 파서 (이중 인코딩 대응)
function deepParse(raw) {
  try {
    let parsed = raw;
    while (typeof parsed === "string") parsed = JSON.parse(parsed);
    return parsed;
  } catch {
    return raw;
  }
}

  // 하루 중 가장 최신 영상 감정만 불러오기 (KST)
router.get("/day", async (req, res) => {
  try {
    const { user_id, date } = req.query;
    if (!user_id)
      return res.status(400).json({ ok: false, message: "user_id 필요" });

    // 한국시간 기준
    const koreaTime = new Date();
    const targetDate =
      !date || date === "undefined" || date.trim() === ""
        ? koreaTime.toISOString().split("T")[0]
        : date;

    console.log("/results/day 호출:", { user_id, targetDate });

    // 하루 중 가장 최근 영상만 가져오기 (이미 KST로 저장됨)
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
      console.log("오늘 감정 데이터 없음");
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

    // 행동 텍스트 처리
    let actions = [];
    if (latest.actions) {
      const raw = latest.actions.trim();
      if (raw.includes("\n")) actions = raw.split("\n").map((s) => s.trim());
      else if (raw.includes(",")) actions = raw.split(",").map((s) => s.trim());
      else actions = [raw];
    }

    // 음악 추천
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
        musicList =
          typeof raw === "string" ? deepParse(raw) : Array.isArray(raw) ? raw : [];
      }
    } catch (err) {
      console.error("음악 데이터 조회 실패:", err.message);
    }

    // 결과 반환
    res.json({
      ok: true,
      avg_distribution: {
        joy: dist.joy || 0,
        sad: dist.sad || 0,
        anger: dist.anger || 0,
        neutral: dist.neutral || 0,
        surprise: dist.surprise || 0,
      },
      feedback: latest.feedback || "",
      actions,
      music: Array.isArray(musicList) ? musicList : [],
    });
  } catch (err) {
    console.error("/results/day 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

  // 각 날짜별 가장 최근 감정만 불러오기 (KST)
router.get("/range", async (req, res) => {
  try {
    const { start, end, user_id } = req.query;
    if (!start || !end || !user_id)
      return res
        .status(400)
        .json({ ok: false, message: "start, end, user_id 필요" });

    const [rows] = await pool.query(
      `
      SELECT r1.*
      FROM analysis_results r1
      INNER JOIN (
          SELECT DATE(created_at) AS day,
                 MAX(created_at) AS latest_time
          FROM analysis_results
          WHERE user_id = ?
            AND DATE(created_at)
                BETWEEN DATE(?) AND DATE(?)
          GROUP BY day
      ) r2
      ON DATE(r1.created_at) = r2.day
         AND r1.created_at = r2.latest_time
      WHERE r1.user_id = ?
      ORDER BY r1.created_at ASC;
      `,
      [user_id, start, end, user_id]
    );

    if (!rows.length) return res.json([]);

    const result = rows.map((r) => {
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

    res.json(result);
  } catch (err) {
    console.error("/results/range 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

   // Flask 리포트 연동 (KST)
router.get("/report/weekly", async (req, res) => {
  try {
    const { start, end, user_id } = req.query;
    if (!start || !end || !user_id)
      return res
        .status(400)
        .json({ ok: false, message: "start, end, user_id 필요" });

    const flaskUrl = "http://13.124.149.204:5001/report/weekly";
    console.log("Flask 주간 리포트 요청:", flaskUrl, { start, end, user_id });

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
    console.error("/report/weekly 오류:", err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

  // GPT 코칭 문장 생성
router.post("/report/weekly-insight", async (req, res) => {
  try {
    // Flutter에서 오는 실제 key 맞추기
    const {
      intense_date,
      stable_date,
      user_id,
      start,
      end
    } = req.body;

    if (!intense_date || !stable_date || !user_id) {
      return res.status(400).json({
        ok: false,
        message: "intense_date, stable_date, user_id 필요",
      });
    }

    // Node 내부에서 사용할 변수로 매핑
    const intense = intense_date;
    const stable  = stable_date;

    // 주간 평균 감정 GET
    const weeklyUrl = "http://13.124.149.204:5001/report/weekly";
    const wk = await axios.get(weeklyUrl, {
      params: { start, end, user_id },
    });

    const avgDist =
      wk.data?.avg_distribution ||
      wk.data?.result?.avg_distribution ||
      {};

    // Flask 인사이트 POST
    const flaskUrl = "http://13.124.149.204:5001/report/weekly-insight";
    const g = await axios.post(flaskUrl, {
      intense_date: intense,
      stable_date: stable,
      avg_dist: avgDist,
    });

    return res.json({
      ok: true,
      insight: g.data?.insight || "",
    });

  } catch (err) {
    console.error("weekly-insight 오류:", err.message);
    return res.status(500).json({ ok: false, error: err.message });
  }
});

export default router;
