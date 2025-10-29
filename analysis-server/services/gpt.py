# services/gpt.py
import os, json
from typing import List, Dict

# === 환경 ===
USE_GPT = os.getenv("USE_GPT_FEEDBACK", "false").lower() == "true"
API_KEY = os.getenv("OPENAI_API_KEY", "")
MODEL = os.getenv("GPT_MODEL", "gpt-4o-mini")

# 한국어 우선 설정 (원하면 .env에서 바꿀 수 있음)
MUSIC_LOCALE = os.getenv("MUSIC_LOCALE", "ko")  # 'ko'|'en'...
KOREAN_FIRST = os.getenv("MUSIC_KOREAN_FIRST", "true").lower() == "true"

# ---- OpenAI 클라이언트 ----
_client = None
def _client_ok():
    global _client
    if not (USE_GPT and API_KEY):
        return False
    try:
        from openai import OpenAI
        if _client is None:
            _client = OpenAI(api_key=API_KEY)
        return True
    except Exception:
        return False


# ================= 단건 피드백 =================
def make_feedback(kdate: str, fused_dist: Dict[str,float], transcript: str) -> str:
    """한 건 분석 요약 (일간)"""
    if not _client_ok(): return ""
    prompt = f"""오늘 날짜: {kdate}
다음 감정 분포(0~1)와 대화를 참고해 2~4문장으로 **간결한 한국어** 요약을 작성해 주세요.
- 지나친 훈계/판단은 피하고, 짧은 공감과 격려를 포함
- 마크다운/목록 금지, 문장만

감정 분포: {json.dumps(fused_dist, ensure_ascii=False)}
대화 전사(있으면 활용): {transcript}
"""
    rsp = _client.chat.completions.create(
        model=MODEL,
        messages=[{"role":"system","content":"You are a kind, concise Korean mental-wellness coach."},
                  {"role":"user","content":prompt}],
        temperature=0.6,
    )
    return (rsp.choices[0].message.content or "").strip()


# ================= 주간 피드백 =================
def make_weekly_feedback(start: str, end: str, avg_pct: Dict[str,float], sample_count: int = 0) -> str:
    """주간 요약 (서버에서 행동 라인은 제거)"""
    if not _client_ok(): return ""
    prompt = f"""기간: {start} ~ {end}
주간 평균 감정 분포(0~1): {json.dumps(avg_pct, ensure_ascii=False)}
샘플 수: {sample_count}

요청:
- 3~5문장으로 한국어 요약
- 필요하면 1~3개의 '행동1:', '행동2:' 형태의 짧은 실천 팁을 제시
- 과한 전문용어/지시는 금지
"""
    rsp = _client.chat.completions.create(
        model=MODEL,
        messages=[{"role":"system","content":"You are a concise, supportive Korean coach."},
                  {"role":"user","content":prompt}],
        temperature=0.6,
    )
    return (rsp.choices[0].message.content or "").strip()


# ================= 한국어 음악 추천 =================
def make_music_recs(emotion: str, count: int = 5, locale: str | None = None) -> List[Dict[str,str]]:
    """
    감정(emotion: joy|sad|anger|neutral|surprise)에 어울리는 곡 추천.
    한국어 응답을 강제하고, 가능한 한 **국내/한국어 곡을 우선** 추천하도록 지시.
    반환: [{title, artist, reason, (optional) link}]
    """
    if not _client_ok(): return []

    loc = (locale or MUSIC_LOCALE or "ko").lower()
    # 한국어 강제·형식 강제 프롬프트
    korean_rule = "반드시 한국어로만 작성하세요. 영어 문장/설명 금지." if loc == "ko" else "Return in the requested locale."

    prefer_kr = ""
    if KOREAN_FIRST and loc == "ko":
        prefer_kr = "가능하면 한국 가요(국내 아티스트/한국어 가사)를 우선 추천하세요. 해외곡이 더 적합하면 1곡 정도는 허용합니다."

    prompt = f"""
당신은 감정 기반 음악 큐레이터입니다.
감정: {emotion}
요청 곡 수: {count}

요청:
- {korean_rule}
- 각 항목은 JSON 배열의 원소로, 정확히 다음 키를 포함: title, artist, reason, link
- reason은 한 문장, 따뜻하고 간결하게 (문장부호 포함 30자 내외)
- link는 가능하면 유튜브 공식/공식채널 링크 사용, 없으면 빈 문자열("")
- {prefer_kr}

출력은 **JSON 배열만** 반환하세요. 설명/코드블록/추가문구 금지.

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

        # 코드블록 제거
        if txt.startswith("```"):
            # ```json ... ``` 형태 처리
            lines = [ln for ln in txt.splitlines() if not ln.strip().startswith("```")]
            txt = "\n".join(lines).strip()

        data = json.loads(txt)
        out: List[Dict[str,str]] = []
        for it in data:
            title = (it.get("title") or "").strip()
            artist = (it.get("artist") or "").strip()
            reason = (it.get("reason") or "").strip()
            link = (it.get("link") or "").strip()
            if title and artist:
                out.append({"title": title, "artist": artist, "reason": reason, "link": link})
        # 요청 개수로 컷
        return out[:max(1, count)]
    except Exception:
        # 파싱 실패 시 빈 리스트 (서버에서 기본곡으로 보완됨)
        return []
