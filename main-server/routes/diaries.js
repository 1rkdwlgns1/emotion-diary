// routes/diaries.js
import express from "express";
import { verifyToken } from "../middlewares/auth.js";
import pool from "../db.js";

const router = express.Router();

// ✅ 일기 작성 (로그인 필요)
router.post("/", verifyToken, async (req, res) => {
  try {
    const { content, emotion_label } = req.body;
    const { user_id } = req.user; // 토큰에서 user_id 추출

    if (!content) {
      return res.status(400).json({ ok: false, message: "일기 내용을 입력하세요." });
    }

    await pool
      .promise()
      .query(
        "INSERT INTO diaries (user_id, content, emotion_label) VALUES (?, ?, ?)",
        [user_id, content, emotion_label || null]
      );

    res.json({ ok: true, message: "일기 저장 완료!" });
  } catch (err) {
    console.error("일기 작성 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// ✅ 내 일기 목록 조회 (로그인 필요)
router.get("/", verifyToken, async (req, res) => {
  try {
    const { user_id } = req.user;
    const [rows] = await pool
      .promise()
      .query(
        "SELECT diary_id, content, emotion_label, created_at FROM diaries WHERE user_id = ? ORDER BY created_at DESC",
        [user_id]
      );

    res.json({ ok: true, diaries: rows });
  } catch (err) {
    console.error("일기 조회 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

export default router;
