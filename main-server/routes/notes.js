import express from "express";
import pool from "../db.js";

const router = express.Router();


  //오늘의 감정 메모 저장
router.post("/save", async (req, res) => {
  try {
    const { user_id, memo } = req.body;
    if (!user_id) {
      return res.status(400).json({ ok: false, message: "user_id 누락됨" });
    }

    // 동일 날짜에 이미 존재하면 덮어쓰기
    await pool.query(
      `
      INSERT INTO emotion_notes (user_id, content, created_at)
      VALUES (?, ?, NOW())
      ON DUPLICATE KEY UPDATE content = VALUES(content)
      `,
      [user_id, memo || "(메모 없음)"]
    );

    res.json({ ok: true, message: "메모 저장 완료" });
  } catch (err) {
    console.error("메모 저장 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});


  // 특정 날짜 메모 조회 (캘린더용)
router.get("/day", async (req, res) => {
  try {
    const { user_id, date } = req.query;
    if (!user_id || !date) {
      return res.status(400).json({ ok: false, message: "user_id 또는 date 누락" });
    }

    const [rows] = await pool.query(
      `
      SELECT content
      FROM emotion_notes
      WHERE user_id = ? AND DATE(created_at) = DATE(?)
      `,
      [user_id, date]
    );

    res.json({ ok: true, memo: rows[0]?.content || "" });
  } catch (err) {
    console.error("메모 조회 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// 오늘의 메모 조회
router.get("/day", async (req, res) => {
  try {
    const { user_id, date } = req.query;
    if (!user_id) return res.status(400).json({ ok: false, message: "user_id 필요" });

    const [rows] = await pool.query(
      `
      SELECT content, note_date
      FROM emotion_notes
      WHERE user_id = ?
        AND DATE(note_date) = DATE(?)
      LIMIT 1
      `,
      [user_id, date || new Date()]
    );

    if (rows.length === 0) {
      return res.json({ ok: false, message: "메모 없음" });
    }

    res.json({ ok: true, memo: rows[0].content });
  } catch (err) {
    console.error("메모 조회 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

export default router;
