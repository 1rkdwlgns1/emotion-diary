import mysql from "mysql2";
import dotenv from "dotenv";

dotenv.config();

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT,
});

pool.getConnection((err, connection) => {
  if (err) {
    console.error("❌ MySQL 연결 실패:", err.message);
  } else {
    console.log("✅ MySQL 연결 성공!");
    connection.release();
  }
});

export default pool;
