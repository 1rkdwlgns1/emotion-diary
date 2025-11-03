// routes/analysis.js
import express from "express";
import axios from "axios";
import dotenv from "dotenv";
import pool from "../db.js";

dotenv.config();
const router = express.Router();

// ✅ Flask 서버 주소 (분석 요청용)
const FLASK_URL = process.env.FLASK_URL || "http://127.0.0.1:5001/analyze";

/* =====================================================
   Flask 응답 파서 (널 안전 처리)
===================================================== */
function extractAnalysis(flaskData) {
  const result = flaskData?.result || {};
  const fused = result.fused || {};
  const text = result.text || {};

  const label = fused.final_label || "unknown";
  const dist =
    fused.distribution ||
    result.face?.distribution ||
    result.text?.distribution ||
    {};
  const confidence = fused.confidence || 0.0;
  const transcript = text.transcript || "";
  const feedback = result.feedback || "";

  return { label, dist, confidence, transcript, feedback };
}

/* =====================================================
   1️⃣ /analysis/analyze
   Node → Flask 감정분석 요청 → 결과 저장
===================================================== */
router.post("/analyze", async (req, res) => {
  const { user_id, media_id, s3Key } = req.body;

  if (!s3Key || !user_id) {
    console.error("❌ 필수값 누락:", req.body);
    return res.status(400).json({
      ok: false,
      message: "user_id 또는 s3Key 누락됨",
    });
  }

  try {
    // ① 분석 요청 DB 등록
    const [insertRes] = await pool.query(
      `INSERT INTO analysis_request (user_id, media_id, status, requested_at)
       VALUES (?, ?, 'pending', NOW())`,
      [user_id, media_id]
    );
    const requestId = insertRes.insertId;
    console.log(`🧠 분석 요청 생성 완료 (request_id=${requestId})`);

    // ② Flask로 분석 요청
    console.log(`📡 Flask 요청 시작 → ${FLASK_URL}`);
    const response = await axios.post(FLASK_URL, {
      s3_key: s3Key,
      bucket: process.env.AWS_S3_BUCKET,
      user_id,
      media_id,
      request_id: requestId,
    });

    console.log("✅ Flask 응답 수신 성공");
    const { label, dist, confidence, transcript, feedback } = extractAnalysis(response.data);

    // ③ emotion_result 저장
    const [resultInsert] = await pool.query(
      `INSERT IGNORE INTO emotion_result
        (request_id, user_id, media_id, top_emotion, emotion_detail,
         transcript, confidence, feedback, source_model, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'Fusion-v1', NOW())`,
      [
        requestId,
        user_id,
        media_id,
        label,
        JSON.stringify(dist),
        transcript,
        confidence,
        feedback || null,
      ]
    );

    if (resultInsert.affectedRows === 0) {
      console.log(`ℹ️ 감정결과 이미 존재 (request_id=${requestId})`);
    } else {
      console.log(`💾 감정 결과 저장 완료 (result_id=${resultInsert.insertId})`);
    }

    // ④ 요청 상태 업데이트
    await pool.query(
      `UPDATE analysis_request SET status='done', completed_at=NOW()
       WHERE request_id=?`,
      [requestId]
    );

    res.json({
      ok: true,
      message: "Flask 분석 및 결과 저장 완료",
      request_id: requestId,
      result_id: resultInsert.insertId || null,
      flaskResponse: response.data,
    });
  } catch (err) {
    console.error("❌ 분석 처리 오류:", err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

/* =====================================================
   2️⃣ /analysis/result
   Flask → Node 콜백 (비동기 저장)
===================================================== */
router.post("/result", async (req, res) => {
  try {
    const data = req.body || {};
    const request_id = data.request_id || req.query.request_id;
    const user_id = data.user_id || req.query.user_id;
    const media_id = data.media_id || req.query.media_id;
    const result = data.result || {};

    if (!request_id || !user_id || !media_id) {
      console.warn("⚠️ 콜백: 필드 누락", data);
      return res.status(200).json({
        ok: false,
        message: "⚠️ 필드 누락됨 (로그만 표시)",
      });
    }

    await pool.query(
      `INSERT IGNORE INTO analysis_request (request_id, user_id, media_id, requested_at, status)
       VALUES (?, ?, ?, NOW(), 'done')`,
      [request_id, user_id, media_id]
    );

    const { label, dist, confidence, transcript, feedback } = extractAnalysis({ result });

    const [insert] = await pool.query(
      `INSERT IGNORE INTO emotion_result
        (request_id, user_id, media_id, top_emotion, emotion_detail,
         transcript, confidence, feedback, source_model, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'Fusion-v1', NOW())`,
      [
        request_id,
        user_id,
        media_id,
        label,
        JSON.stringify(dist),
        transcript,
        confidence,
        feedback || null,
      ]
    );

    await pool.query(
      `UPDATE analysis_request SET status='done', completed_at=NOW()
       WHERE request_id=?`,
      [request_id]
    );

    console.log(`✅ Flask 콜백 완료 (request_id=${request_id})`);

    res.json({
      ok: true,
      message: "Flask 콜백 저장 완료",
      result_id: insert.insertId || null,
    });
  } catch (err) {
    console.error("❌ 콜백 저장 오류:", err);
    res.status(200).json({ ok: false, error: err.message });
  }
});

export default router;
