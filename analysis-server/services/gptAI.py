import os, json, logging, traceback
from typing import List, Dict, Optional

# 환경 변수 로드
USE_GPT = os.getenv("USE_GPT_AI", "true").lower() == "true"
API_KEY = os.getenv("OPENAI_API_KEY", "")
MODEL = os.getenv("GPT_MODEL_AI", "gpt-4o-mini")

_client = None
def _client_ok():
    """OpenAI 클라이언트 준비 확인"""
    global _client
    if not (USE_GPT and API_KEY):
        logging.getLogger("analysis-server").warning("❌ 감정이(GPT-AI) 비활성화 또는 API_KEY 없음")
        return False
    try:
        from openai import OpenAI
        if _client is None:
            _client = OpenAI(api_key=API_KEY)
        return True
    except Exception as e:
        logging.getLogger("analysis-server").exception(f"❌ 감정이 클라이언트 생성 실패: {e}")
        return False


# 감정이 대화 엔진
def make_chat_reply(message: str, history: list = None, emotion: str = "neutral") -> str:
    if not _client_ok():
        import random
        base_replies = [
            "그랬구나… 마음이 많이 힘들었겠다 😢",
            "응, 그럴 수 있어. 그래도 이렇게 말해줘서 고마워 ☕",
            "괜찮아, 오늘은 조금 쉬자 😊",
        ]
        return random.choice(base_replies)

    # 최근 대화 맥락 3턴
    context = ""
    if history:
        for u, b in history[-3:]:
            context += f"[사용자] {u}\n[감정이] {b}\n"

    # User prompt: 오직 맥락 + 메시지 + 감정만 전달
    prompt = f"""
[최근 대화 맥락]
{context}

[현재 사용자 메시지]
{message}

[사용자 감정 상태]
{emotion}

위 내용을 참고하여 감정이로서 자연스럽게 1회 답변하세요.
"""

    try:
        rsp = _client.chat.completions.create(
            model=MODEL,
            messages=[
                {
                    "role": "system",
                    "content": """
당신은 인간처럼 자연스럽게 대화하는 감정 친구 ‘감정이’입니다.
상대가 느끼는 감정을 섬세하게 읽고, 따뜻한 공감을 바탕으로 부드러운 대화를 이어갑니다.
당신의 목표는 상담사가 아닌 진짜 사람처럼 감정에 공감하고 자연스럽게 이야기하는 것입니다.

지침:
1. 첫 문장은 반드시 공감 표현으로 시작합니다.
   예: 그랬구나…, 이해돼…, 그럴 수 있지…, 에구 많이 힘들었겠다…
2. 두 번째 문장에서는 감정의 이유·상황을 짧게 짚어 주세요.
   사용자가 말한 핵심 감정(슬픔 분노 지침 기쁨 놀람 등)을 자연스럽게 반영합니다.
   직접 과장하거나 판단하지 않기.
3. 세 번째 문장은 자연스러운 이어말 또는 질문으로 대화를 확장합니다.
   예: 지금은 좀 괜찮아?, 그 일 때문에 아직 마음이 남아 있어?, 요즘 어떤 일로 위로받고 있어?
4. 전체 문장은 2~3개, 길이는 80자 이내로 합니다.
5. 말투는 부드럽고 일상적인 친구 스타일이어야 합니다.
6. 이모티콘은 최대 1개만 자연스럽게 사용합니다.
7. 분석적·전문가적 말투 금지. 상담사처럼 말하면 안 됩니다.
8. 사용자의 감정 신호(힘들다 좋았다 짜증난다 속상하다 지쳤어 등)를 반드시 반영합니다.
9. 사용자의 맥락을 기억하되 과도한 예측이나 단정 짓지 않습니다.
10. 다음과 같은 종료 신호가 나오면 질문 없이 한 문장으로 마무리합니다:
    그만, 괜찮아, 됐어, 싫어, 말하기 싫어
    예: 알겠어. 말하고 싶은 날에 이야기해 줘 ☕
11. 부정적 감정에는 가볍게, 긍정적 감정에는 밝게 톤을 조절합니다.
12. 사용자가 가볍게 말하면 가볍게, 진지하면 진지하게 톤을 맞출 것.

중요:
영어 금지
따옴표 금지
불릿포인트 금지
이모티콘 과다 금지
오버 공감 금지
"""
                },
                {"role": "user", "content": prompt.strip()},
            ],
            temperature=0.85,
            max_tokens=220,
        )

        txt = (rsp.choices[0].message.content or "").strip()
        txt = txt.strip('"').strip("'").replace("```", "").strip()
        return txt

    except Exception as e:
        logging.getLogger("analysis-server").exception(f"make_chat_reply 실패: {e}")
        return "그랬구나… 오늘은 조금 쉬자 ☕"
