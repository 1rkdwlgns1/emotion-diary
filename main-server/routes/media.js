import express from "express";
import { S3Client } from "@aws-sdk/client-s3";
import multer from "multer";
import multerS3 from "multer-s3-v3";
import dotenv from "dotenv";
import pool from "../db.js";

dotenv.config();
const router = express.Router();

// 환경 변수 정리 (공백/개행 방지)
const {
  AWS_ACCESS_KEY_ID,
  AWS_SECRET_ACCESS_KEY,
  AWS_REGION,
  AWS_S3_BUCKET,
} = {
  AWS_ACCESS_KEY_ID: process.env.AWS_ACCESS_KEY_ID?.trim(),
  AWS_SECRET_ACCESS_KEY: process.env.AWS_SECRET_ACCESS_KEY?.trim(),
  AWS_REGION: process.env.AWS_REGION?.trim(),
  AWS_S3_BUCKET: process.env.AWS_S3_BUCKET?.trim(),
};


// S3 클라이언트 설정
const s3 = new S3Client({
  region: AWS_REGION,
  credentials: {
    accessKeyId: AWS_ACCESS_KEY_ID,
    secretAccessKey: AWS_SECRET_ACCESS_KEY,
  },
});

// multer + S3 업로드 설정
const upload = multer({
  storage: multerS3({
    s3,
    bucket: AWS_S3_BUCKET,
    acl: "private",
    contentType: multerS3.AUTO_CONTENT_TYPE,
    key: (req, file, cb) => {
      // user_id를 파일명에 포함시켜 누락 방지
      const userId = req.body?.user_id || "unknown";
      const fileName = `videos/${userId}_${Date.now()}_${file.originalname}`;
      cb(null, fileName);
    },
  }),
  limits: { fileSize: 1024 * 1024 * 200 },
});

// 업로드만 수행 (Flask 호출 제거)
router.post("/upload", (req, res) => {
  upload.single("file")(req, res, async (err) => {
    if (err) {
      console.error("S3 업로드 오류:", err);
      return res.status(500).json({ ok: false, error: err.message });
    }

    // 빈 요청 자동 무시 (Flutter 재요청/비정상 요청 방지)
    if (!req.file && (!req.body || Object.keys(req.body).length === 0)) {
      console.warn("빈 업로드 요청 무시됨 (Flutter 재요청)");
      return res.json({ ok: false, message: "빈 요청 무시됨" });
    }

    console.log("업로드 요청 수신:", req.body);

    const userId = req.body?.user_id || req.query?.user_id;
    const mediaType = req.body?.media_type || "video";

    if (!userId || userId === "unknown") {
      console.error("user_id 누락:", req.body);
      return res.json({ ok: false, message: "user_id 누락됨 (무시됨)" });
    }

    try {
      const fileName = req.file.originalname;
      const s3Key = req.file.key;

      // DB 저장
      const [result] = await pool.query(
        `INSERT INTO media (user_id, media_type, file_name, s3_key, status, created_at)
         VALUES (?, ?, ?, ?, 'uploaded', NOW())`,
        [userId, mediaType, fileName, s3Key]
      );

      const mediaId = result.insertId;
      console.log(`업로드 성공 → DB 저장 완료 (media_id=${mediaId})`);

      // Flask 호출 제거
      return res.json({
        ok: true,
        message: "S3 업로드 완료 (분석은 별도 요청에서 진행)",
        media_id: mediaId,
        s3Key,
      });
    } catch (error) {
      console.error("DB 저장 오류:", error);
      return res.status(500).json({ ok: false, error: error.message });
    }
  });
});

export default router;
