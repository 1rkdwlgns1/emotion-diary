// index.js
import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import bodyParser from "body-parser";

import mediaRoutes from "./routes/media.js";
import analysisRoutes from "./routes/analysis.js";
import userRoutes from "./routes/users.js";
import resultsRoutes from "./routes/results.js"; // ✅ 반드시 추가!!!

import pool from "./db.js";

dotenv.config();
const app = express();
const PORT = process.env.PORT || 3000;

// ✅ 미들웨어
app.use(cors());
app.use(express.json());
app.use(bodyParser.urlencoded({ extended: true }));

// ✅ 라우트 연결
app.use("/media", mediaRoutes);
app.use("/analysis", analysisRoutes);
app.use("/users", userRoutes);
app.use("/results", resultsRoutes); // ✅ 여기 results.js 연결 (핵심)

// ✅ 기본 라우트 테스트
app.get("/", (req, res) => {
  res.json({ ok: true, message: "Emotion Diary Node API is running" });
});

// ✅ DB 연결 테스트
(async () => {
  try {
    const conn = await pool.getConnection();
    console.log("✅ MySQL 연결 성공");
    conn.release();
  } catch (err) {
    console.error("❌ MySQL 연결 실패:", err.message);
  }
})();

// ✅ 서버 실행
app.listen(PORT, "0.0.0.0", () => {
  console.log(`✅ Server running at http://0.0.0.0:${PORT}`);
});

console.log("✅ ENV 테스트:", {
  DB_NAME: process.env.DB_NAME,
  AWS_REGION: process.env.AWS_REGION,
  BUCKET: process.env.AWS_S3_BUCKET,
});
