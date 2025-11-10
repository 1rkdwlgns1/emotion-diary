# services/gpt.py
import os, json, logging, traceback
from typing import List, Dict, Optional

# === 환경 변수 로드 ===
USE_GPT = os.getenv("USE_GPT_FEEDBACK", "false").lower() == "true"
API_KEY = os.getenv("OPENAI_API_KEY", "")
MODEL = os.getenv("GPT_MODEL", "gpt-4o-mini")

# === 한국어 우선 설정 ===
MUSIC_LOCALE = os.getenv("MUSIC_LOCALE", "ko")
KOREAN_FIRST = os.getenv("MUSIC_KOREAN_FIRST", "true").lower() == "true"

# ---- OpenAI 클라이언트 ----
_client = None
def _client_ok():
    """OpenAI 클라이언트 준비 확인"""
    global _client
    if not (USE_GPT and API_KEY):
        logging.getLogger("analysis-server").warning("❌ GPT 비활성화 또는 API_KEY 없음")
        return False
    try:
        from openai import OpenAI
        if _client is None:
            _client = OpenAI(api_key=API_KEY)
        return True
    except Exception as e:
        logging.getLogger("analysis-server").exception(f"❌ GPT 클라이언트 생성 실패: {e}")
        return False


# ================= 감정 피드백 =================
def make_feedback(kdate: str, fused_dist: Dict[str, float], transcript: str) -> str:
    """감정 분포 + 발화 텍스트 기반 피드백 생성"""
    if not _client_ok():
        return ""

    prompt = f"""
당신은 감정 분석 전문 상담가입니다.
아래는 사용자의 발화 내용(STT 텍스트)과 감정 분석 결과입니다.

[사용자 발화 요약]
{transcript}

[감정 분석 결과]
{json.dumps(fused_dist, ensure_ascii=False)}

지침:
1. 사용자의 말 속 맥락을 이해하고 감정에 맞는 피드백을 2~3문장으로 작성하세요.
2. **따옴표, 코드블록, 영어 문장 금지.**
3. **공감 중심으로 자연스럽게 작성.**
오늘 날짜: {kdate}
"""
    try:
        rsp = _client.chat.completions.create(
            model=MODEL,
            messages=[
                {
                    "role": "system",
                    "content": "You are a kind Korean emotional coach who writes short, natural feedback in Korean."
                },
                {"role": "user", "content": prompt.strip()},
            ],
            temperature=0.7,
        )
        content = (rsp.choices[0].message.content or "").strip()
        if content.startswith('"') and content.endswith('"'):
            content = content[1:-1].strip()
        return content
    except Exception as e:
        logging.getLogger("analysis-server").exception(f"Feedback 생성 실패: {e}")
        traceback.print_exc()
        return ""


# ================= 행동 추천 =================
def make_actions(fused_dist: Dict[str, float], transcript: str) -> str:
    """감정 데이터와 STT 텍스트를 바탕으로 감정 회복 행동 3줄 텍스트 생성"""
    if not _client_ok():
        return ""

    dominant = max(fused_dist, key=fused_dist.get)
    strength = fused_dist[dominant]

    prompt = f"""
당신은 감정 분석을 기반으로 맞춤 조언을 주는 한국어 감정 코치입니다.
아래는 사용자의 발화 요약(STT 텍스트)과 감정 분석 결과입니다.

[사용자 발화 요약]
{transcript}

[감정 분석 결과]
{json.dumps(fused_dist, ensure_ascii=False)}

지침:
1. 사용자의 감정을 해석하고, 오늘 실천할 수 있는 감정 회복 행동 3가지를 제안하세요.
2. 각 행동은 한 줄에 하나씩, 간결하고 자연스러운 문장으로 작성하세요.
3. **번호, 따옴표, 코드블록, 불릿, 영어 금지.**
4. 오직 한국어 3줄만 출력하세요. 예시:
   복식호흡으로 진정하기
   스트레칭 10분
   산책하며 생각 정리하기
5. 감정 강도는 {strength:.2f}이며, {"감정이 강한 상태" if strength > 0.5 else "안정적인 상태"}입니다.
"""

    try:
        rsp = _client.chat.completions.create(
            model=MODEL,
            messages=[
                {
                    "role": "system",
                    "content": "You are a Korean emotional coach. Respond ONLY with exactly 3 plain text lines in Korean. No lists, no quotes, no explanations."
                },
                {"role": "user", "content": prompt.strip()},
            ],
            temperature=0.8,
        )

        txt = (rsp.choices[0].message.content or "").strip()
        print("[GPT raw actions]", txt)
        txt = txt.replace("```", "").replace('"', "").replace("'", "").strip()
        lines = [ln.strip("-• ").strip() for ln in txt.splitlines() if ln.strip()]

        if len(lines) < 3:
            parts = txt.replace("  ", " ").split()
            if len(parts) >= 3:
                lines = [" ".join(parts[i:i+2]) for i in range(0, len(parts), 2)][:3]

        if not lines:
            lines = ["심호흡으로 진정하기", "조용한 음악 듣기", "가벼운 산책하기"]

        return "\n".join(lines[:3])

    except Exception as e:
        logging.getLogger("analysis-server").exception(f"make_actions 실패: {e}")
        traceback.print_exc()
        return ""


# ================= 음악 추천 =================
def make_music_recs(
    emotion: str,
    count: int = 5,
    locale: Optional[str] = None,
    avoid_titles: Optional[List[str]] = None,
) -> List[Dict[str, str]]:
    if not _client_ok():
        return []

    loc = (locale or MUSIC_LOCALE or "ko").lower()
    korean_rule = "반드시 한국어로만 작성하세요. 영어 문장 금지." if loc == "ko" else "Return in the requested locale."
    prefer_kr = ""
    if KOREAN_FIRST and loc == "ko":
        prefer_kr = "가능하면 한국 가요(국내 아티스트/한국어 가사)를 우선 추천하세요."

    avoid = [t.lower() for t in (avoid_titles or [])]

    prompt = f"""
당신은 감정 기반 음악 큐레이터입니다.
감정: {emotion}
요청 곡 수: {count}

요청:
- {korean_rule}
- 각 항목은 JSON 배열의 원소로, 다음 키를 포함: title, artist, reason, link
- reason은 한 문장(30자 내외)으로 간결하게.
- link는 유튜브 공식 채널 링크 또는 빈 문자열.
- {prefer_kr}
- 아래 곡명은 제외: {json.dumps(avoid, ensure_ascii=False)}

출력은 JSON 배열만 반환하세요. 예시:
[
  {{"title":"블루밍","artist":"아이유","reason":"밝은 무드가 기쁨과 잘 어울려요.","link":"https://www.youtube.com/watch?v=D1PvIWdJ8xo"}}
]
"""
    try:
        rsp = _client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": "You are a helpful Korean music curator who responds only with valid JSON."},
                {"role": "user", "content": prompt.strip()},
            ],
            temperature=0.8,
        )
        txt = (rsp.choices[0].message.content or "").strip()
        if txt.startswith("```"):
            lines = [ln for ln in txt.splitlines() if not ln.strip().startswith("```")]
            txt = "\n".join(lines).strip()
        txt = txt.strip().lstrip("`").rstrip("`")

        data = json.loads(txt)
        out: List[Dict[str, str]] = []
        for it in data:
            title = (it.get("title") or "").strip()
            artist = (it.get("artist") or "").strip()
            reason = (it.get("reason") or "").strip()
            link = (it.get("link") or "").strip()
            if title and artist:
                if title.lower() in avoid:
                    continue
                out.append({"title": title, "artist": artist, "reason": reason, "link": link})
        return out[:max(1, count)]
    except Exception as e:
        logging.getLogger("analysis-server").exception(f"Music recommendation failed: {e}")
        traceback.print_exc()
        return []


# ================= 주간 감정 요약 (GPT 피드백) =================
def make_weekly_feedback(start, end, avg, sample_count=0):
    """주간 감정 평균 기반 GPT 요약 생성"""
    try:
        if not _client_ok():
            return "⚠️ GPT 비활성화 상태입니다 (.env 확인 필요)"
        if not avg or sum(avg.values()) == 0:
            return "이번 주에는 감정 데이터가 충분하지 않아 분석을 제공할 수 없습니다."

        prompt = f"""
당신은 감정 분석 리포트를 작성하는 따뜻한 한국어 심리상담가입니다.
다음은 {start}부터 {end}까지의 감정 분석 평균 결과입니다.
전체 {sample_count}건의 데이터를 기반으로 작성해주세요.

감정 비율:
- 기쁨: {avg.get('joy', 0):.1f}%
- 슬픔: {avg.get('sad', 0):.1f}%
- 분노: {avg.get('anger', 0):.1f}%
- 평온: {avg.get('neutral', 0):.1f}%
- 놀람: {avg.get('surprise', 0):.1f}%

지침:
1. 한 주간의 감정 경향을 따뜻하게 요약하세요.
2. 2~4문장으로 작성하세요.
3. **따옴표, 코드블록, 영어 금지.**
4. 긍정적인 마무리 문장을 포함하세요.
"""

        rsp = _client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": "You are a kind Korean emotional analyst writing in Korean."},
                {"role": "user", "content": prompt.strip()},
            ],
            temperature=0.7,
            max_tokens=400,
        )

        fb = (rsp.choices[0].message.content or "").strip()
        return fb or "이번 주 감정 요약을 생성하지 못했습니다."
    except Exception as e:
        logging.getLogger("analysis-server").warning(f"⚠️ make_weekly_feedback 오류: {e}")
        traceback.print_exc()
        return "이번 주 감정 요약을 생성하지 못했습니다."
