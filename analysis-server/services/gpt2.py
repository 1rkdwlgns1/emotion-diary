# services/gpt2.py
import os, json, logging, traceback
from typing import List, Dict, Optional

USE_GPT = os.getenv("USE_GPT_FEEDBACK", "false").lower() == "true"
API_KEY = os.getenv("OPENAI_API_KEY", "")
MODEL = os.getenv("GPT2_MODEL", "gpt-4o-mini")

_client = None

def _client_ok():
    """OpenAI 클라이언트 준비 확인"""
    global _client
    if not (USE_GPT and API_KEY):
        logging.getLogger("analysis-server").warning("❌ GPT2 비활성화 또는 API_KEY 없음")
        return False
    try:
        from openai import OpenAI
        if _client is None:
            _client = OpenAI(api_key=API_KEY)
        return True
    except Exception as e:
        logging.getLogger("analysis-server").exception(f"❌ GPT2 클라이언트 생성 실패: {e}")
        return False


# ================= 🎵 음악 추천 (GPT2 버전) =================
def make_music_recs(
    emotion: str,
    count: int = 5,
    locale: Optional[str] = "ko",
    avoid_titles: Optional[List[str]] = None,
) -> List[Dict[str, str]]:
    """GPT2 모델을 이용해 감정 기반 음악 추천"""
    if not _client_ok():
        return []

    avoid = [t.lower() for t in (avoid_titles or [])]
    prompt = f"""
당신은 감정 기반 음악 큐레이터입니다.
현재 사용자의 주요 감정은 '{emotion}'입니다.

요청사항:
- 한국어로만 작성.
- JSON 배열 형태로 응답.
- 각 항목은 title, artist, reason, link 필드를 포함해야 합니다.
- link는 유튜브 공식 영상이나 검색 결과 링크를 사용하세요.
- 곡 수: {count}곡
- 제외할 곡명: {json.dumps(avoid, ensure_ascii=False)}

출력 예시:
[
  {{"title":"블루밍","artist":"아이유","reason":"밝은 분위기로 기쁨과 잘 어울려요.","link":"https://www.youtube.com/watch?v=D1PvIWdJ8xo"}}
]
"""

    try:
        rsp = _client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": "You are a Korean music curator who responds only with valid JSON."},
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
                out.append({
                    "title": title,
                    "artist": artist,
                    "reason": reason,
                    "link": link,
                })
        return out[:max(1, count)]

    except Exception as e:
        logging.getLogger("analysis-server").exception(f"GPT2 Music recommendation failed: {e}")
        traceback.print_exc()
        return []
