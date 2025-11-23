import nodemailer from "nodemailer";
import dotenv from "dotenv";

dotenv.config();

const transporter = nodemailer.createTransport({
  service: process.env.MAIL_SERVICE,
  auth: {
    user: process.env.MAIL_USER,
    pass: process.env.MAIL_PASS,
  },
});

export async function sendResetEmail(to, tempPassword) {
  const mailOptions = {
    from: `"Emotion Diary 💚" <${process.env.MAIL_USER}>`,
    to,
    subject: "[Emotion Diary] 임시 비밀번호 안내",
    html: `
      <div style="font-family: Pretendard, sans-serif; line-height: 1.6;">
        <h2>안녕하세요 😊</h2>
        <p>요청하신 임시 비밀번호를 안내드립니다.</p>
        <div style="background:#F0F3EE; padding:14px; border-radius:8px; margin:10px 0;">
          <strong style="font-size:18px; color:#333;">${tempPassword}</strong>
        </div>
        <p>로그인 후 꼭 비밀번호를 변경해 주세요.</p>
        <br/>
        <p style="color:#777;">Emotion Diary 팀</p>
      </div>
    `,
  };

  await transporter.sendMail(mailOptions);
}
