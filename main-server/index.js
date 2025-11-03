// index.js
import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import bodyParser from "body-parser";
import mediaRoutes from "./routes/media.js";
import analysisRoutes from "./routes/analysis.js";
import userRoutes from "./routes/users.js";
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

// ✅ 서버 테스트
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
//app.listen(PORT, () => {
//  console.log(`✅ Server running at http://localhost:${PORT}`);
//});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Server running at http://0.0.0.0:${PORT}`);
});
