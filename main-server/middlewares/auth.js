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
