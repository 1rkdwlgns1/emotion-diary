import express from "express";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { verifyToken } from "../middlewares/auth.js";
import pool from "../db.js";

const router = express.Router();

/* ✅ 회원가입 */
router.post("/register", async (req, res) => {
  try {
    const { email, password, nickname } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        ok: false,
        message: "이메일과 비밀번호를 입력하세요.",
      });
    }

    const [rows] = await pool.query("SELECT * FROM users WHERE email = ?", [
      email,
    ]);
    if (rows.length > 0) {
      return res.status(409).json({
        ok: false,
        message: "이미 존재하는 이메일입니다.",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    await pool.query(
      "INSERT INTO users (email, password_hash, nickname) VALUES (?, ?, ?)",
      [email, hashedPassword, nickname]
    );

    res.json({ ok: true, message: "회원가입 성공!" });
  } catch (err) {
    console.error("❌ 회원가입 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

/* ✅ 로그인 */
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res
        .status(400)
        .json({ ok: false, message: "이메일과 비밀번호를 입력하세요." });
    }

    const [rows] = await pool.query("SELECT * FROM users WHERE email = ?", [
      email,
    ]);
    if (rows.length === 0) {
      return res
        .status(401)
        .json({ ok: false, message: "존재하지 않는 이메일입니다." });
    }

    const user = rows[0];
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res
        .status(401)
        .json({ ok: false, message: "비밀번호가 올바르지 않습니다." });
    }

    const token = jwt.sign(
      { user_id: user.user_id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: "2h" }
    );

    res.json({
      ok: true,
      message: "로그인 성공!",
      token,
      user: {
        user_id: user.user_id,
        email: user.email,
        nickname: user.nickname,
      },
    });
  } catch (err) {
    console.error("❌ 로그인 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

/* ✅ 프로필 업데이트 */
router.put("/me", verifyToken, async (req, res) => {
  try {
    const { user_id } = req.user;
    const { nickname, gender, age, mbti } = req.body;

    if (!gender || !age || !mbti) {
      return res
        .status(400)
        .json({ ok: false, message: "필수 정보가 누락되었습니다." });
    }

    await pool.query(
      "UPDATE users SET nickname=?, gender=?, age=?, mbti=? WHERE user_id=?",
      [nickname, gender, age, mbti, user_id]
    );

    res.json({ ok: true, message: "프로필 업데이트 성공!" });
  } catch (err) {
    console.error("❌ 프로필 업데이트 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

/* ✅ 내 정보 조회 */
router.get("/me", verifyToken, async (req, res) => {
  try {
    const { user_id } = req.user;
    const [rows] = await pool.query(
      "SELECT user_id, email, nickname, created_at FROM users WHERE user_id=?",
      [user_id]
    );
    if (rows.length === 0) {
      return res
        .status(404)
        .json({ ok: false, message: "유저를 찾을 수 없습니다." });
    }
    res.json({ ok: true, user: rows[0] });
  } catch (err) {
    console.error("❌ 내 정보 조회 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

/* ✅ 관심사 저장 */
router.post("/interests", verifyToken, async (req, res) => {
  try {
    const { user_id } = req.user;
    const { interests } = req.body;

    if (!Array.isArray(interests) || interests.length === 0) {
      return res
        .status(400)
        .json({ ok: false, message: "관심사를 1개 이상 선택하세요." });
    }

    for (const name of interests) {
      await pool.query(
        "INSERT IGNORE INTO interests (interest_name) VALUES (?)",
        [name]
      );
    }

    await pool.query("DELETE FROM user_interests WHERE user_id=?", [user_id]);

    for (const name of interests) {
      const [rows] = await pool.query(
        "SELECT interest_id FROM interests WHERE interest_name=?",
        [name]
      );
      if (rows.length > 0) {
        const id = rows[0].interest_id;
        await pool.query(
          "INSERT INTO user_interests (user_id, interest_id) VALUES (?, ?)",
          [user_id, id]
        );
      }
    }

    res.json({ ok: true, message: "관심사 저장 완료!" });
  } catch (err) {
    console.error("❌ 관심사 저장 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

export default router;
