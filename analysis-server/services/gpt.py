import os, json, logging, traceback
from typing import List, Dict, Optional

# 환경 변수 로드
USE_GPT = os.getenv("USE_GPT_FEEDBACK", "false").lower() == "true"
API_KEY = os.getenv("OPENAI_API_KEY", "")
MODEL = os.getenv("GPT_MODEL", "gpt-4o-mini")

# 한국어 우선 설정
MUSIC_LOCALE = os.getenv("MUSIC_LOCALE", "ko")
KOREAN_FIRST = os.getenv("MUSIC_KOREAN_FIRST", "true").lower() == "true"

# OpenAI 클라이언트
_client = None
def _client_ok():
    """OpenAI 클라이언트 준비 확인"""
    global _client
    if not (USE_GPT and API_KEY):
        logging.getLogger("analysis-server").warning("GPT 비활성화 또는 API_KEY 없음")
        return False
    try:
        from openai import OpenAI
        if _client is None:
            _client = OpenAI(api_key=API_KEY)
        return True
    except Exception as e:
        logging.getLogger("analysis-server").exception(f"GPT 클라이언트 생성 실패: {e}")
        return False



# 감정 피드백
def make_feedback(kdate: str, fused_dist: Dict[str, float], transcript: str) -> str:
    """STT 텍스트 + 감정 데이터 기반 감정 피드백 (3~4문장 버전)"""
    if not _client_ok():
        return ""

    prompt = f"""
당신은 사용자의 발화 내용(STT 텍스트)과 감정 분석 데이터를 함께 이해해
감정의 흐름과 맥락을 짚어주는 한국어 감정 코치입니다.

[사용자 발화 내용]
{transcript}

[감정 분석 결과]
{json.dumps(fused_dist, ensure_ascii=False)}

지침:
1. 발화 내용과 감정 분포를 함께 고려해 사용자의 감정 상태를 따뜻하게 요약하세요.
2. 피드백은 3~4문장, 약 150~200자 정도로 자연스럽게 작성하세요.
3. 첫 문장은 감정의 전반적인 느낌, 두 번째는 이유나 맥락, 마지막은 부드러운 제안이나 정리로 마무리하세요.
4. "괜찮아요", "힘내세요", "이야기 나눠주세요" 같은 상담 멘트는 사용하지 마세요.
5. 전문적 분석어나 사회적 표현(예: 현대사회, 일반적으로)은 금지합니다.
6. STT 오타가 있을 경우 의미를 유지한 채 자연스럽게 수정해 반영하세요.
7. 예시:
   - 오늘의 말 속에는 깊은 슬픔과 상실감이 느껴져요. 감정 데이터에서도 비슷한 흐름이 보여요. 마음속의 여운이 오래 남을 수 있지만, 그 감정 또한 자신을 이해하는 과정일 거예요.
   - 오늘은 분노와 답답함이 함께 느껴졌어요. 무언가 풀리지 않는 감정이 쌓여 있었던 것 같아요. 잠시 거리를 두고 스스로를 다독이는 시간이 필요할지도 몰라요.
   - 밝은 표현 속에서도 약간의 피로감이 전해지네요. 감정 데이터에서도 평온함과 기쁨이 함께 나타나요. 스스로에게 휴식을 허락해주는 것도 좋은 선택이에요.
오늘 날짜: {kdate}
"""

    try:
        rsp = _client.chat.completions.create(
            model=MODEL,
            messages=[
                {
                    "role": "system",
                    "content": "You are a Korean emotional coach. Write 3–4 natural Korean sentences (150–200 characters) combining STT tone and emotion data. Keep it warm, empathetic, and contextual."
                },
                {"role": "user", "content": prompt.strip()},
            ],
            temperature=0.8,
        )
        content = (rsp.choices[0].message.content or "").strip()
        if content.startswith('"') and content.endswith('"'):
            content = content[1:-1].strip()
        return content
    except Exception as e:
        logging.getLogger("analysis-server").exception(f"Feedback 생성 실패: {e}")
        traceback.print_exc()
        return ""
# 행동 추천
def make_actions(fused_dist: Dict[str, float], transcript: str) -> str:
    """감정 데이터 + STT 내용 기반 행동 추천"""
    if not _client_ok():
        return ""

    dominant = max(fused_dist, key=fused_dist.get)
    strength = fused_dist[dominant]

    prompt = f"""
당신은 감정 분석 기반으로 '상황 맞춤형 행동 3줄'만 제안하는 한국어 감정 코치입니다.

[사용자 발화 요약(STT)]
{transcript}

[감정 분석 결과]
주요 감정: {dominant}
감정 강도: {strength:.2f}
전체 분포: {json.dumps(fused_dist, ensure_ascii=False)}

출력 규칙
1. **3줄만** 작성.
2. **한 줄은 14~18자 사이의 짧고 명확한 문장**.
3. **상황(STT 내용) + 감정(분석값)을 반영한 ‘바로 할 수 있는 활동’만 추천**.
4. 감정 공감/설명/조언/위로 금지(그건 피드백 영역).
5. **번호, 따옴표, 영어, 불릿 금지.**
6. 너무 일반 명령형(X) → 자연스럽고 부드럽게 제안(O)
7. 예시 스타일:
   감정을 잠시 정돈해보세요
   좋아하는 음악을 들어보세요
   마음이 편한 공간에 머물러보세요
"""

    try:
        rsp = _client.chat.completions.create(
            model=MODEL,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "당신은 상황 맞춤형 감정 회복 행동을 생성하는 한국어 코치입니다. "
                        "반드시 3줄의 짧은 문장으로만 응답하세요. "
                        "설명·리스트·따옴표·영어 금지."
                    )
                },
                {"role": "user", "content": prompt.strip()},
            ],
            temperature=0.85,
        )

        txt = (rsp.choices[0].message.content or "").strip()
        print("[GPT raw actions]", txt)

        # 포맷 정리
        txt = txt.replace("```", "").replace('"', "").replace("'", "").strip()
        lines = [ln.strip("-• ").strip() for ln in txt.splitlines() if ln.strip()]

        # 3줄 미만 보정
        if len(lines) < 3:
            basic = ["심호흡으로 진정해보세요", "조용한 음악을 들어보세요", "잠시 산책해보세요"]
            lines += basic[:(3 - len(lines))]

        return "\n".join(lines[:3])

    except Exception as e:
        logging.getLogger("analysis-server").exception(f"make_actions 실패: {e}")
        return ""

# 음악 추천
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


# 주간 감정 요약 (GPT 피드백)
def make_weekly_feedback(start, end, avg, sample_count=0):
    """주간 감정 평균 기반 GPT 요약 생성"""
    try:
        if not _client_ok():
            return "GPT 비활성화 상태입니다 (.env 확인 필요)"
        if not avg or sum(avg.values()) == 0:
            return "이번 주에는 감정 데이터가 충분하지 않아 분석을 제공할 수 없습니다."

        prompt = f"""
당신은 사용자의 한 주간 감정을 부드럽게 해석하는 한국어 감정 리포트 작성자입니다.
상담사가 아니라, 사용자의 기록을 따뜻하게 정리해주는 분석가입니다.
아래는 {start}부터 {end}까지의 평균 감정 데이터이며, 총 {sample_count}개의 표본을 기반으로 합니다.

감정 비율:
- 기쁨: {avg.get('joy', 0):.1f}%
- 슬픔: {avg.get('sad', 0):.1f}%
- 분노: {avg.get('anger', 0):.1f}%
- 평온: {avg.get('neutral', 0):.1f}%
- 놀람: {avg.get('surprise', 0):.1f}%

지침:
1. 상담사가 아닌 **따뜻한 분석가**처럼 작성하세요.
2. 한 주간의 흐름을 자연스럽게 정리하는 **3~4문장**으로 작성하세요.
3. 감정의 변화나 패턴을 부드럽게 해석하세요. 과한 조언 금지.
4. 전문용어, 심리학 용어, 딱딱한 표현 금지.
5. 따옴표, 영어, 코드블록 금지.
6. 마지막 문장은 가벼운 긍정적 여운으로 마무리하세요.
"""

        rsp = _client.chat.completions.create(
            model=MODEL,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are a warm Korean emotional analyst who writes soft and natural weekly summaries. "
                        "Write 3–4 smooth Korean sentences based on emotion data. No English, no quotes."
                    ),
                },
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

# 주간 인사이트 GPT 생성
def make_weekly_insight(intense_date, stable_date, avg_dist):
    """
    인사이트 카드용 GPT 자연어 문장 생성 (자연스럽고 반복 없는 버전)
    intense_date: 감정이 가장 흔들린 날짜 (문자열 YYYY-MM-DD)
    stable_date: 감정이 가장 안정된 날짜 (문자열 YYYY-MM-DD)
    avg_dist: 주간 평균 감정 분포 dict
    """

    if not _client_ok():
        return ""

    prompt = f"""
당신은 모바일 앱의 '감정 기간 리포트'를 작성하는 한국어 감정 코치입니다.
문체는 '친절하지만 전문적이고, 사람처럼 자연스럽게'가 핵심입니다.

입력 데이터:
- 감정이 가장 흔들린 날: {intense_date}
- 가장 안정적이었던 날: {stable_date}
- 기간 평균 감정 비율: {json.dumps(avg_dist, ensure_ascii=False)}

-------------------------------------
[작성 규칙 — 매우 중요]
1) 문장은 총 4~5문장.
2) 초반 2문장은 "해당 기간 초반 흐름"을 자연스럽게 설명.
   - '무거웠어요', '예민했어요' 같은 감정 결을 상황처럼 풀어내기.
   - 과하게 감정적 표현 금지.
3) 다음 2문장은 "후반 흐름이 어떻게 변했는지"를 이어서 설명.
   - '후반으로 갈수록' 같은 반복적인 표현 금지.
   - '흐름이 가라앉았어요', '톤이 부드러워졌어요', '안정된 형태로 자리 잡았어요' 같은 자연어 사용.
   - 초반 내용과 후반 내용을 연결하여 이어진 느낌으로 작성.
4) 마지막(4~5번째) 문장은 가벼운 마무리 문장으로 끝낼 것.
   - 상담 멘트 금지(힘내세요, 괜찮아요 등).
   - '다음 흐름도 더 가벼워질 거예요' 같은 부드러운 제안 OK.
5) 같은 접속어 반복 금지 (예: 후반으로 갈수록 / 후반으로 갈수록 / 시간이 지나면서)
6) 너무 교과서적인 문장 금지. 사람이 말하듯 자연스럽게.

-------------------------------------
[출력 형식 예시 — 구조만 참고]

✨ 이번 기간 초반에는 마음이 조금 무거워지는 순간들이 있었어요.
그날의 분위기를 떠올려보면 감정의 결이 왜 그렇게 움직였는지 자연스럽게 이해돼요.

🌿 며칠 지나면서 흐름이 조금씩 풀리기 시작했고,
감정의 톤이 부드럽게 정리되는 모습이 보였어요.

이번 기간을 가볍게 정리해두면 다음 흐름도 한층 여유롭게 이어질 거예요. ✨

-------------------------------------

위 규칙을 지키며,
반복 없고 자연스럽고 사람스러운 '기간 감정 리포트'를 작성하세요.
"""

    rsp = _client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": "You write Korean emotional insights naturally and smoothly."},
            {"role": "user", "content": prompt},
        ],
        temperature=0.7,
    )

    return (rsp.choices[0].message.content or "").strip()
