const express = require('express');
const app = express();
const PORT = 3000; // 서버가 실행될 포트 번호

// 기본 라우트 (http://localhost:3000 접속 시 보임)
app.get('/', (req, res) => {
  res.send('메인 서버가 정상적으로 실행 중입니다!');
});

// 서버 실행
app.listen(PORT, () => {
  console.log(`✅ 서버 실행 중: http://localhost:${PORT}`);
});
