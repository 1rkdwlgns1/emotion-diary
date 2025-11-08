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


# ================= 단건 피드백 =================
def make_feedback(kdate: str, fused_dist: Dict[str,float], transcript: str) -> str:
    if not _client_ok():
        return ""
    prompt = f"""오늘 날짜: {kdate}
다음 감정 분포(0~1)와 대화를 참고해 2~4문장으로 간결한 한국어 요약을 작성해 주세요.
- 지나친 훈계는 피하고 짧은 공감과 격려 포함
- 마크다운/목록 금지, 문장만

감정 분포: {json.dumps(fused_dist, ensure_ascii=False)}
대화 전사(있으면 활용): {transcript}
"""
    try:
        rsp = _client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": "You are a kind, concise Korean mental-wellness coach."},
                {"role": "user", "content": prompt},
            ],
            temperature=0.6,
        )
        return (rsp.choices[0].message.content or "").strip()
    except Exception as e:
        logging.getLogger("analysis-server").exception(f"Feedback 생성 실패: {e}")
        traceback.print_exc()
        return ""


# ================= 주간 피드백 =================
def make_weekly_feedback(start: str, end: str, avg_pct: Dict[str,float], sample_count: int = 0) -> str:
    if not _client_ok():
        return ""
    prompt = f"""기간: {start} ~ {end}
주간 평균 감정 분포(0~1): {json.dumps(avg_pct, ensure_ascii=False)}
샘플 수: {sample_count}

요청:
- 3~5문장 한국어 요약
- 필요시 1~3개의 '행동1:' 형식의 짧은 실천 팁
- 과한 전문용어 금지
"""
    try:
        rsp = _client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": "You are a concise, supportive Korean coach."},
                {"role": "user", "content": prompt},
            ],
            temperature=0.6,
        )
        return (rsp.choices[0].message.content or "").strip()
    except Exception as e:
        logging.getLogger("analysis-server").exception(f"Weekly feedback 생성 실패: {e}")
        traceback.print_exc()
        return ""


# ================= 음악 추천 =================
def make_music_recs(
    emotion: str,
    count: int = 5,
    locale: Optional[str] = None,
    avoid_titles: Optional[List[str]] = None,
) -> List[Dict[str, str]]:
    """
    감정(emotion: joy|sad|anger|neutral|surprise)에 어울리는 곡 추천.
    반환: [{title, artist, reason, link}]
    """
    if not _client_ok():
        return []

    loc = (locale or MUSIC_LOCALE or "ko").lower()
    korean_rule = "반드시 한국어로만 작성하세요. 영어 문장 금지." if loc == "ko" else "Return in the requested locale."
    prefer_kr = ""
    if KOREAN_FIRST and loc == "ko":
        prefer_kr = "가능하면 한국 가요(국내 아티스트/한국어 가사)를 우선 추천하세요. 해외곡이 더 적합하면 1곡 정도는 포함해도 됩니다."

    avoid = [t.lower() for t in (avoid_titles or [])]

    prompt = f"""
당신은 감정 기반 음악 큐레이터입니다.
감정: {emotion}
요청 곡 수: {count}

요청:
- {korean_rule}
- 각 항목은 JSON 배열의 원소로, 정확히 다음 키를 포함: title, artist, reason, link
- reason은 한 문장(30자 내외)으로 따뜻하고 간결하게
- link는 가능하면 유튜브 공식/공식채널, 없으면 빈 문자열("")
- {prefer_kr}
- 아래 제목(대소문자 무시)과 같은 곡은 피하세요: {json.dumps(avoid, ensure_ascii=False)}

출력은 JSON 배열만 반환하세요. 설명/코드블록 금지.
예시:
[
  {{"title":"블루밍","artist":"아이유","reason":"밝은 무드가 기쁨과 잘 어울려요.","link":"https://www.youtube.com/watch?v=D1PvIWdJ8xo"}},
  {{"title":"사건의 지평선","artist":"윤하","reason":"경쾌한 리듬이 마음을 가볍게 해줘요.","link":"https://www.youtube.com/watch?v=rPgaYeq9NvI"}}
]
"""

    try:
        rsp = _client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": "You are a helpful Korean music curator."},
                {"role": "user", "content": prompt.strip()},
            ],
            temperature=0.8,
        )
        txt = (rsp.choices[0].message.content or "").strip()

        # ```json ... ``` 제거
        if txt.startswith("```"):
            lines = [ln for ln in txt.splitlines() if not ln.strip().startswith("```")]
            txt = "\n".join(lines).strip()

        txt = txt.strip().lstrip("`").rstrip("`")  # 혹시 남은 백틱 제거

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
        logger = logging.getLogger("analysis-server")
        logger.exception(f"Music recommendation failed: {e}")
        traceback.print_exc()
        return []
