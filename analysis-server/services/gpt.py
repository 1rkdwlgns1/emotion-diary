# services/gpt.py
import os, logging
from openai import OpenAI

log = logging.getLogger("analysis-server")

MODEL = os.getenv("GPT_MODEL", "gpt-4o-mini")
USE_GPT = os.getenv("USE_GPT_FEEDBACK", "false").lower() == "true"
API_KEY = os.getenv("OPENAI_API_KEY", "")

# 요약 길이 넉넉히
MAX_TOKENS = int(os.getenv("GPT_MAX_TOKENS", "360"))
TEMPERATURE = float(os.getenv("GPT_TEMPERATURE", "0.7"))
TONE = os.getenv("GPT_TONE", "warm")
AVOID_EMOJI = os.getenv("GPT_AVOID_EMOJI", "false").lower() == "true"

_client = OpenAI(api_key=API_KEY) if (USE_GPT and API_KEY) else None
log.info(f"GPT: USE_GPT={USE_GPT}, MODEL={MODEL}, CLIENT={'ok' if _client else 'none'}")

def _percent(v: float) -> str:
    try: return f"{round(float(v)*100)}%"
    except: return "0%"

def _main_ko(d: dict) -> str:
    if not d: return "불확실"
    key = max(d, key=d.get)
    return {"joy":"기쁨","sad":"슬픔","anger":"분노","surprise":"놀람","neutral":"평온"}.get(key,"불확실")

def _dist_ko_lines(d: dict) -> str:
    order = ["joy","sad","anger","surprise","neutral"]
    ko = {"joy":"기쁨","sad":"슬픔","anger":"분노","surprise":"놀람","neutral":"평온"}
    return "\n".join([f"- {ko[k]}: {_percent(d.get(k,0))}" for k in order])

def _clip(txt: str, limit=1000): return (txt or "").strip()[:limit]

def _is_neutralish(d: dict) -> bool:
    if not d: return True
    vals = {k: float(d.get(k,0.0)) for k in ["joy","sad","anger","surprise","neutral"]}
    top_label = max(vals, key=vals.get)
    top = vals[top_label]
    sorted_vals = sorted(vals.values(), reverse=True)
    gap = (sorted_vals[0] - (sorted_vals[1] if len(sorted_vals)>1 else 0.0))
    return (top_label == "neutral") or (top < 0.40) or (gap < 0.08)

def _style_guards():
    ban = "이모지 사용 금지." if AVOID_EMOJI else "이모지는 최대 1개까지만."
    return (
        "한국어(존댓말)만. 모욕/비난/폭력 표현 금지. 의학적 진단/치료 단정 금지. "
        "숫자·퍼센트 재진술 금지. " + ban
    )

def _tone_sentence_rule():
    if TONE == "neutral": return "어조는 담백하고 중립적으로."
    if TONE == "concise": return "문장은 간결하게 하되 딱딱하지 않게."
    return "따뜻하고 공감적으로. 단정/명령투 지양."

def _summary_instruction():
    # 분석/주간 화면 모두에 쓸 3~5문장 요약
    return (
      "먼저 3~5문장으로 핵심 요약을 작성하세요. "
      "첫 문장은 공감, 이어서 현재 상태를 다루는 실질적인 조언을 포함하세요. "
      "문장마다 같은 어휘 반복을 피하고, 읽기 편한 자연스러운 호흡으로."
    )

def _actions_instruction():
    # Today / 주간 리포트에서 쓰는 행동 3줄
    return (
      "이후 줄바꿈 후 다음 형식으로 오늘 바로 가능한 행동을 3줄 제시하세요.\n"
      "행동1: <12자 내외 동사형>\n행동2: <12자 내외 동사형>\n행동3: <12자 내외 동사형>\n"
      "예: '3분 호흡', '가벼운 산책', '좋아하는 음악 듣기'\n"
      "행동 문구는 중복 없이 간단하게."
    )

def build_prompt(kdate: str, fused_dist: dict, transcript: str):
    base_guard = f"{_tone_sentence_rule()} {_style_guards()}"
    common_tail = f"{_summary_instruction()} {_actions_instruction()}"

    if _is_neutralish(fused_dist or {}):
        sys = (
            "당신은 간결한 감정 코치입니다. 지금은 감정이 한쪽으로 뚜렷하지 않은 "
            "중립/혼합 상태입니다. 감정을 단정하지 말고, 신체감각·호흡·정리 등 "
            "자기돌봄 중심의 안내에 집중하세요. " + base_guard + " " + common_tail
        )
        usr = (
            f"분석일: {kdate}\n"
            "상태: 중립/혼합(감정이 고르게 보임 혹은 확신도 낮음)\n"
            f"감정 분포(참고):\n{_dist_ko_lines(fused_dist or {})}\n\n"
            f"발화(요약 입력):\n{_clip(transcript or '') or '(내용 없음)'}\n\n"
            "요청: 요약 3~5문장 + 행동1~3."
        )
    else:
        sys = (
            "당신은 간결한 감정 코치입니다. 감정 분포와 발화를 참고해 "
            "오늘을 위한 핵심 코칭 요약과 실행 가능한 행동을 제시하세요. "
            + base_guard + " " + common_tail
        )
        usr = (
            f"분석일: {kdate}\n"
            f"주요 감정(모델 판단): {_main_ko(fused_dist or {})}\n"
            f"감정 분포(참고):\n{_dist_ko_lines(fused_dist or {})}\n\n"
            f"발화(요약 입력):\n{_clip(transcript or '') or '(내용 없음)'}\n\n"
            "요청: 요약 3~5문장 + 행동1~3."
        )
    return sys, usr

def make_feedback(kdate: str, fused_dist: dict, transcript: str) -> str | None:
    if not _client:
        log.warning("GPT feedback skipped: client not initialized")
        return None
    sys, usr = build_prompt(kdate, fused_dist, transcript)
    try:
        r = _client.chat.completions.create(
            model=MODEL,
            messages=[{"role":"system","content":sys},{"role":"user","content":usr}],
            max_tokens=MAX_TOKENS,
            temperature=TEMPERATURE,
        )
        msg = (r.choices[0].message.content or "").strip()
        msg = "\n".join([ln.strip() for ln in msg.splitlines() if ln.strip()])
        return msg[:1200]
    except Exception as e:
        log.warning(f"GPT feedback skipped: {e}")
        return None

# === 주간 리포트용 GPT 요약/행동 생성 ===
def make_weekly_feedback(start_date: str, end_date: str, avg_dist: dict, sample_count: int) -> str | None:
    if not _client:
        log.warning("GPT weekly feedback skipped: client not initialized")
        return None

    def _dist_week_ko_lines(d: dict) -> str:
        order = ["joy","sad","anger","surprise","neutral"]
        ko = {"joy":"기쁨","sad":"슬픔","anger":"분노","surprise":"놀람","neutral":"평온"}
        return "\n".join([f"- {ko[k]}: {_percent(d.get(k,0))}" for k in order])

    sys = (
        "당신은 차분한 감정 코치입니다. 지난 1주간 감정 분포 평균을 보고, "
        "사용자가 스스로 조절할 수 있는 가벼운 실천을 제안하세요. "
        f"{_tone_sentence_rule()} {_style_guards()} "
        "먼저 3~5문장으로 주간 요약을 작성하고, 줄바꿈 뒤에 아래 형식으로 행동 3개를 제시하세요.\n"
        "행동1: <12자 내외 동사형>\n행동2: <12자 내외 동사형>\n행동3: <12자 내외 동사형>"
    )

    usr = (
        f"기간: {start_date} ~ {end_date}\n"
        f"표본 수: {sample_count}개\n"
        f"주간 감정 분포(평균, 참고):\n{_dist_week_ko_lines(avg_dist or {})}\n\n"
        "요청: 주간 경향을 부드럽게 요약(단정/비난 금지)하고, 오늘 바로 가능한 3가지 행동을 위 형식으로 제시하세요."
    )

    try:
        r = _client.chat.completions.create(
            model=MODEL,
            messages=[{"role":"system","content":sys},{"role":"user","content":usr}],
            max_tokens=max(360, MAX_TOKENS),
            temperature=TEMPERATURE,
        )
        msg = (r.choices[0].message.content or "").strip()
        msg = "\n".join([ln.strip() for ln in msg.splitlines() if ln.strip()])
        return msg[:1200]
    except Exception as e:
        log.warning(f"GPT weekly feedback skipped: {e}")
        return None
