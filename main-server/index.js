// index.js
import express from "express";
import dotenv from "dotenv";
import pool from "./db.js"; // 방금 만든 db 연결 재사용
import cors from "cors";
import userRoutes from "./routes/users.js";
import diaryRoutes from "./routes/diaries.js";


dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());

// 바디 JSON 파싱
app.use(express.json());

app.use("/users", userRoutes);
app.use("/diaries", diaryRoutes);


// 서버 살아있는지 체크
app.get("/", (req, res) => {
  res.send("✅ Emotion Diary API Server Running!");
});

// DB 연결도 같이 체크
app.get("/health", (req, res) => {
  pool.query("SELECT 1 AS ok", (err, rows) => {
    if (err) return res.status(500).json({ ok: false, error: err.message });
    res.json({ ok: true, db: rows[0].ok }); // { ok: true, db: 1 }
  });
});

app.listen(PORT, () => {
  console.log(`✅ Server running at http://localhost:${PORT}`);
});
