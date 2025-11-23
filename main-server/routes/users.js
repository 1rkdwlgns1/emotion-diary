import express from "express";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import nodemailer from "nodemailer";
import { verifyToken } from "../middlewares/auth.js";
import pool from "../db.js";

const router = express.Router();

// 회원가입
router.post("/register", async (req, res) => {
  try {
    const { email, password, nickname } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        ok: false,
        message: "이메일과 비밀번호를 입력하세요.",
      });
    }

    const [rows] = await pool.query("SELECT * FROM users WHERE email = ?", [email]);
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
    console.error("회원가입 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// 로그인
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({
        ok: false,
        message: "이메일과 비밀번호를 입력하세요.",
      });
    }

    const [rows] = await pool.query("SELECT * FROM users WHERE email = ?", [email]);
    if (rows.length === 0) {
      return res.status(401).json({
        ok: false,
        message: "존재하지 않는 이메일입니다.",
      });
    }

    const user = rows[0];
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({
        ok: false,
        message: "비밀번호가 올바르지 않습니다.",
      });
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
    console.error("로그인 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// 프로필 업데이트
router.put("/me", verifyToken, async (req, res) => {
  try {
    const { user_id } = req.user;
    const { nickname, gender, age, mbti } = req.body;

    if (!gender || !age || !mbti) {
      return res.status(400).json({ ok: false, message: "필수 정보가 누락되었습니다." });
    }

    await pool.query(
      "UPDATE users SET nickname=?, gender=?, age=?, mbti=? WHERE user_id=?",
      [nickname, gender, age, mbti, user_id]
    );

    res.json({ ok: true, message: "프로필 업데이트 성공!" });
  } catch (err) {
    console.error("프로필 업데이트 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

// 내 정보 조회
router.get("/me", verifyToken, async (req, res) => {
  try {
    const { user_id } = req.user;
    const [rows] = await pool.query(
      "SELECT user_id, email, nickname, created_at FROM users WHERE user_id=?",
      [user_id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ ok: false, message: "유저를 찾을 수 없습니다." });
    }
    res.json({ ok: true, user: rows[0] });
  } catch (err) {
    console.error("내 정보 조회 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});


  // 비밀번호 재설정 이메일 요청 (자동 Gmail/Naver 구분)
router.post("/reset-password-request", async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ ok: false, message: "이메일을 입력하세요." });
    }

    const [rows] = await pool.query("SELECT * FROM users WHERE email = ?", [email]);
    if (rows.length === 0) {
      return res.status(404).json({ ok: false, message: "등록되지 않은 이메일입니다." });
    }

    // 임시 비밀번호 생성
    const tempPw = Math.random().toString(36).slice(-8);
    const hashed = await bcrypt.hash(tempPw, 10);
    await pool.query("UPDATE users SET password_hash = ? WHERE email = ?", [hashed, email]);

    // 이메일 도메인 감지
    const domain = email.split("@")[1];
    let transporter;

    if (domain === "gmail.com") {
      transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: process.env.MAIL_USER,
          pass: process.env.MAIL_PASS,
        },
      });
    } else if (domain === "naver.com") {
      transporter = nodemailer.createTransport({
        host: "smtp.naver.com",
        port: 465,
        secure: true,
        auth: {
          user: process.env.NAVER_USER,
          pass: process.env.NAVER_PASS,
        },
      });
    } else {
      return res.status(400).json({
        ok: false,
        message: "지원되지 않는 이메일 도메인입니다. (Gmail 또는 Naver만 가능)",
      });
    }

    // 이메일 내용
    const mailOptions = {
      from: `"감정 다이어리" <${
        domain === "gmail.com" ? process.env.MAIL_USER : process.env.NAVER_USER
      }>`,
      to: email,
      subject: "임시 비밀번호 안내",
      html: `
        <h2>감정 다이어리 비밀번호 재설정 안내</h2>
        <p>안녕하세요 😊</p>
        <p>요청하신 임시 비밀번호는 아래와 같습니다.</p>
        <div style="background:#f4f4f4;padding:10px;font-size:18px;border-radius:6px;width:fit-content;">
          <b>${tempPw}</b>
        </div>
        <p>로그인 후 반드시 새 비밀번호로 변경해주세요.</p>
      `,
    };

    await transporter.sendMail(mailOptions);
    res.json({ ok: true, message: "임시 비밀번호가 이메일로 전송되었습니다." });
  } catch (err) {
    console.error("❌ 비밀번호 재설정 요청 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});
// 비밀번호 변경 (로그인된 상태에서)
router.post("/change-password", verifyToken, async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;
    const { user_id } = req.user;

    if (!oldPassword || !newPassword)
      return res.status(400).json({ ok: false, message: "이메일 또는 비밀번호가 없습니다." });

    const [rows] = await pool.query("SELECT password_hash FROM users WHERE user_id=?", [user_id]);
    if (rows.length === 0)
      return res.status(404).json({ ok: false, message: "유저를 찾을 수 없습니다." });

    const user = rows[0];
    const match = await bcrypt.compare(oldPassword, user.password_hash);
    if (!match)
      return res.status(401).json({ ok: false, message: "기존 비밀번호가 일치하지 않습니다." });

    const newHashed = await bcrypt.hash(newPassword, 10);
    await pool.query("UPDATE users SET password_hash=? WHERE user_id=?", [newHashed, user_id]);

    res.json({ ok: true, message: "비밀번호가 변경되었습니다." });
  } catch (err) {
    console.error("비밀번호 변경 오류:", err);
    res.status(500).json({ ok: false, message: err.message });
  }
});


// 비밀번호 재설정
router.post("/reset-password", async (req, res) => {
  try {
    const { email, newPassword } = req.body;

    if (!email || !newPassword) {
      return res.status(400).json({ ok: false, message: "이메일 또는 비밀번호가 없습니다." });
    }

    const [rows] = await pool.query("SELECT * FROM users WHERE email = ?", [email]);
    if (rows.length === 0) {
      return res.status(404).json({ ok: false, message: "존재하지 않는 이메일입니다." });
    }

    const hashed = await bcrypt.hash(newPassword, 10);
    await pool.query("UPDATE users SET password_hash = ? WHERE email = ?", [hashed, email]);

    res.json({ ok: true, message: "비밀번호 변경 완료!" });
  } catch (err) {
    console.error("비밀번호 재설정 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});
// 관심사 저장 
router.post("/interests", verifyToken, async (req, res) => {
  try {
    const { user_id } = req.user;
    const { interests } = req.body;

    if (!Array.isArray(interests) || interests.length === 0) {
      return res.status(400).json({
        ok: false,
        message: "관심사를 1개 이상 선택하세요.",
      });
    }

    // 관심사 테이블에 없으면 추가
    for (const name of interests) {
      await pool.query("INSERT IGNORE INTO interests (interest_name) VALUES (?)", [name]);
    }

    // 기존 관심사 삭제
    await pool.query("DELETE FROM user_interests WHERE user_id=?", [user_id]);

    // 새 관심사 연결
    for (const name of interests) {
      const [rows] = await pool.query(
        "SELECT interest_id FROM interests WHERE interest_name=?",
        [name]
      );
      if (rows.length > 0) {
        await pool.query(
          "INSERT INTO user_interests (user_id, interest_id) VALUES (?, ?)",
          [user_id, rows[0].interest_id]
        );
      }
    }

    res.json({ ok: true, message: "관심사 저장 완료!" }); 
  } catch (err) {
    console.error("관심사 저장 오류:", err);
    res.status(500).json({ ok: false, error: err.message });
  }
});

  // 카카오 로그인 
router.post("/kakao-login", async (req, res) => {
  try {
    const { kakao_id, email, nickname } = req.body;

    if (!kakao_id) {
      return res.status(400).json({ ok: false, message: "kakao_id 누락" });
    }

    // kakao_id로 먼저 조회 (이미 카카오 가입된 경우)
    let [rows] = await pool.query(
      "SELECT * FROM users WHERE kakao_id = ? LIMIT 1",
      [kakao_id]
    );

    if (rows.length > 0) {
      const user = rows[0];

      const token = jwt.sign(
        { user_id: user.user_id, email: user.email },
        process.env.JWT_SECRET,
        { expiresIn: "7d" }
      );

      return res.json({
        ok: true,
        isNew: false,   // 기존 회원
        message: "카카오 로그인 성공",
        token,
        user: {
          user_id: user.user_id,
          email: user.email,
          nickname: user.nickname,
        },
      });
    }

    // email이 기존 일반회원과 같으면 → kakao_id 연결
    if (email) {
      const [emailRows] = await pool.query(
        "SELECT * FROM users WHERE email = ? LIMIT 1",
        [email]
      );

      if (emailRows.length > 0) {
        await pool.query(
          "UPDATE users SET kakao_id = ? WHERE email = ?",
          [kakao_id, email]
        );

        const user = emailRows[0];

        const token = jwt.sign(
          { user_id: user.user_id, email: user.email },
          process.env.JWT_SECRET,
          { expiresIn: "7d" }
        );

        return res.json({
          ok: true,
          isNew: false,   // 기존 계정 + 카카오 연동
          message: "기존 계정에 카카오 계정이 연결되었습니다.",
          token,
          user: {
            user_id: user.user_id,
            email: user.email,
            nickname: user.nickname,
          },
        });
      }
    }

    // 신규 회원가입 (email 없어도 NULL 허용)
    const finalNickname = nickname ?? "카카오사용자";

    const [insert] = await pool.query(
      "INSERT INTO users (email, nickname, kakao_id) VALUES (?, ?, ?)",
      [email ?? null, finalNickname, kakao_id]
    );

    const newUserId = insert.insertId;

    const token = jwt.sign(
      { user_id: newUserId, email },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    return res.json({
      ok: true,
      isNew: true,   
      message: "카카오 신규 가입 + 로그인 성공",
      token,
      user: {
        user_id: newUserId,
        email,
        nickname: finalNickname,
      },
    });

  } catch (err) {
    console.error("카카오 로그인 오류:", err);
    return res.status(500).json({ ok: false, error: err.message });
  }
});

export default router; 

// middlewares/auth.js
import jwt from "jsonwebtoken";

export function verifyToken(req, res, next) {
  try {
    const authHeader = req.headers["authorization"];
    if (!authHeader) {
      return res.status(401).json({ ok: false, message: "토큰이 없습니다." });
    }

    // Bearer 분리
    const token = authHeader.split(" ")[1];
    if (!token) {
      return res.status(401).json({ ok: false, message: "토큰 형식이 올바르지 않습니다." });
    }

    // 토큰 검증
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; 
    next(); 
  } catch (err) {
    console.error("JWT 인증 실패:", err.message);
    res.status(401).json({ ok: false, message: "유효하지 않은 토큰입니다." });
  }
}
