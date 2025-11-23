import mysql from "mysql2/promise";
import dotenv from "dotenv";

dotenv.config({ path: "./.env" }); 

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT || 3306,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

try {
  const conn = await pool.getConnection();
  console.log("MySQL 연결 성공:", process.env.DB_NAME, "at", process.env.DB_HOST);
  conn.release();
} catch (err) {
  console.error("MySQL 연결 실패:", err.message);
}

export default pool;
