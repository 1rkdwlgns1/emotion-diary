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


# ================= 단건 피드백 (일간) =================
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


# ================= 주간 피드백 (캘린더용) =================
def make_weekly_feedback(start: str, end: str, avg_pct: Dict[str,float], sample_count: int = 0) -> str:
    """
    주간 요약 (캘린더에서 날짜 범위 선택 시 호출됨)
    """
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


# ================= 음악 추천 (Today 화면용) =================
def make_music_recs(emotion: str, count: int = 5, locale: str | None = None) -> List[Dict[str,str]]:
    """
    감정(emotion: joy|sad|anger|neutral|surprise)에 어울리는 곡 추천.
    한국어 응답을 강제하고, 가능한 한 **국내/한국어 곡을 우선** 추천하도록 지시.
    반환: [{title, artist, reason, (optional) link}]
    """
    if not _client_ok(): return []

    loc = (locale or MUSIC_LOCALE or "ko").lower()
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
        return out[:max(1, count)]
    except Exception:
        return []


# ================= 활동 추천 (Today 화면용) =================
def make_action_recs(emotion: str, count: int = 3) -> List[str]:
    """
    감정(emotion: joy|sad|anger|neutral|surprise)에 어울리는 실천/행동 제안
    TodayEmotionScreen의 '활동추천' 섹션과 연동됨
    """
    # GPT 사용 가능한 경우
    if _client_ok():
        prompt = f"""
당신은 감정 기반 라이프 코치입니다.
현재 감정: {emotion}
요청:
- 짧고 구체적인 한국어 행동 제안 {count}개를 목록으로 작성
- 각 문장은 15자 내외, 따뜻하고 실천 가능한 표현 (예: '따뜻한 차 한잔 마시기')
- 코드블록, 숫자, 불릿 기호 없이 문장만 나열
"""
        try:
            rsp = _client.chat.completions.create(
                model=MODEL,
                messages=[
                    {"role": "system", "content": "You are a concise, positive Korean life coach."},
                    {"role": "user", "content": prompt.strip()},
                ],
                temperature=0.7,
            )
            txt = (rsp.choices[0].message.content or "").strip()
            lines = [ln.strip("-• ").strip() for ln in txt.splitlines() if ln.strip()]
            # 너무 길면 잘라냄
            out = [ln for ln in lines if 2 <= len(ln) <= 30][:count]
            if out:
                return out
        except Exception:
            pass

    # GPT 미사용 시 기본 추천 반환
    defaults = {
        "joy": ["좋았던 순간을 메모로 남기기", "가벼운 산책하며 기분 유지하기"],
        "sad": ["따뜻한 차 마시며 휴식하기", "친한 사람에게 짧은 안부 메시지 보내기"],
        "anger": ["5분 복식호흡으로 긴장 풀기", "빠르게 걷기/가벼운 스트레칭 10분"],
        "surprise": ["새로운 음악 한 곡 탐색하기", "오늘의 놀란 순간 간단 기록하기"],
        "neutral": ["짧은 스트레칭으로 몸 깨우기", "좋아하는 음악 1곡 듣기"]
    }
    return defaults.get(emotion, defaults["neutral"])
