# services/kobert.py
# ================================
# 고급형 감정사전 확장판 (v2.1)
# - CPU 환경 최적화
# - heuristic 감정 단어 60+개 확장
# - zero-shot fallback 포함
# ================================

import os, re
import torch

LABELS7 = ["anger", "disgust", "fear", "joy", "neutral", "sadness", "surprise"]
LABELS5 = ["joy", "sad", "anger", "neutral", "surprise"]

_MODEL_ID = os.getenv("KOBERT_EMO_ID", "jason9693/kobert-emotion-classification")
_DISABLE = os.getenv("KOBERT_DISABLE", "1") == "1"  # 기본 비활성화 (제로샷/휴리스틱 사용)
_tokenizer = None
_model = None
_device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# ===== 감정 키워드 확장 =====
_POS = [
    "기쁘", "좋아", "행복", "즐겁", "재밌", "감사", "사랑", "웃음", "설레", "뿌듯",
    "신나", "기분 좋", "만족", "안심", "평온", "좋았다", "기분이 좋아", "감동", "포근"
]

_NEG_SAD = [
    "슬프", "우울", "눈물", "힘들", "외롭", "서운", "속상", "아쉬워", "허전", "괴롭",
    "후회", "그리워", "그립", "무너졌", "미안", "착잡", "복잡", "죽었", "상처", "괴로워",
    "힘빠", "눈시울", "그리움", "쓸쓸", "억울", "눈물이", "마음이 아파", "슬펐어"
]

_NEG_ANG = [
    "화나", "짜증", "분노", "열받", "빡치", "답답", "불만", "억울", "불쾌", "성질",
    "짜증났", "화났", "짜증나", "짜증이", "불편", "못참겠", "화가", "미치겠", "짜증나서",
    "불만스러", "기분 나빠", "싫어죽겠"
]

_SURP = [
    "깜짝", "놀랐", "놀라", "헉", "예상 못", "충격", "뜻밖", "의외", "황당", "놀라움",
    "당황", "어이없", "믿기지 않", "상상 못", "소름"
]

_NEU = [
    "그냥", "괜찮", "평범", "보통", "무난", "덤덤", "별일", "신경 안", "무감정", "느낌 없음",
    "잘 모르겠", "그래", "뭐랄까", "그렇네", "그랬어", "아무렇지", "별 감정 없음"
]


# ===== 기본 분포 유틸 =====
def _dist5(joy=0, sad=0, anger=0, neutral=1.0, surprise=0):
    s = joy + sad + anger + neutral + surprise
    if s <= 0:
        return {"joy": 0, "sad": 0, "anger": 0, "neutral": 1.0, "surprise": 0}
    return {k: v / s for k, v in {
        "joy": joy, "sad": sad, "anger": anger, "neutral": neutral, "surprise": surprise
    }.items()}


# ===== 단어 기반 휴리스틱 =====
def _heuristic(text: str) -> dict:
    t = (text or "").lower()
    if not t:
        return _dist5()
    score = {"joy": 0.0, "sad": 0.0, "anger": 0.0, "neutral": 0.0, "surprise": 0.0}

    def hit(ws): return any(re.search(w, t) for w in ws)

    if hit(_POS): score["joy"] += 1.0
    if hit(_NEG_SAD): score["sad"] += 1.0
    if hit(_NEG_ANG): score["anger"] += 1.0
    if hit(_SURP): score["surprise"] += 0.8
    if hit(_NEU): score["neutral"] += 1.0

    if sum(score.values()) == 0:
        score["neutral"] = 1.0
    return _dist5(**score)


# ===== KoBERT 모델 로드 =====
def _load_kobert():
    global _tokenizer, _model
    if _tokenizer is None or _model is None:
        from transformers import AutoTokenizer, AutoModelForSequenceClassification
        _tokenizer = AutoTokenizer.from_pretrained(_MODEL_ID)
        _model = AutoModelForSequenceClassification.from_pretrained(_MODEL_ID)
        _model.eval().to(_device)
    return _tokenizer, _model


def _softmax(logits: torch.Tensor) -> torch.Tensor:
    e = torch.exp(logits - logits.max(dim=-1, keepdim=True).values)
    return e / e.sum(dim=-1, keepdim=True)


# ===== 7감정 → 5감정 매핑 =====
def _map7to5(d7: dict) -> dict:
    return {
        "joy": float(d7.get("joy", 0.0)),
        "sad": float(d7.get("sadness", 0.0)) + float(d7.get("fear", 0.0)),
        "anger": float(d7.get("anger", 0.0)) + float(d7.get("disgust", 0.0)),
        "neutral": float(d7.get("neutral", 0.0)),
        "surprise": float(d7.get("surprise", 0.0)),
    }


# ===== KoBERT 예측 =====
def _kobert_predict7(text: str) -> dict:
    tok, mdl = _load_kobert()
    with torch.no_grad():
        inputs = tok(
            (text or "").strip(),
            truncation=True,
            padding=True,
            max_length=128,
            return_tensors="pt"
        ).to(_device)
        logits = mdl(**inputs).logits
        probs = _softmax(logits)[0].cpu().tolist()
    return {lab: float(p) for lab, p in zip(LABELS7, probs)}


# ===== Zero-shot 대체 =====
_zero = None
def _load_zeroshot():
    global _zero
    if _zero is None:
        from transformers import pipeline
        _zero = pipeline("zero-shot-classification",
                         model="joeddav/xlm-roberta-large-xnli",
                         device=0 if torch.cuda.is_available() else -1)
    return _zero


def _zeroshot_predict5(text: str) -> dict:
    z = _load_zeroshot()
    labels = ["joy", "sad", "anger", "neutral", "surprise"]
    res = z((text or "").strip(), candidate_labels=labels,
            hypothesis_template="이 문장의 감정은 {}이다.", multi_label=True)
    scores = {lbl: float(sc) for lbl, sc in zip(res["labels"], res["scores"])}
    total = sum(scores.values()) or 1.0
    return {k: scores.get(k, 0.0) / total for k in labels}


# ===== 통합 예측 =====
def predict7(text: str) -> dict:
    txt = (text or "").strip()
    if not txt:
        return {k: 0.0 for k in LABELS7}
    if _DISABLE:
        try:
            d5 = _zeroshot_predict5(txt)
            return {
                "joy": d5["joy"], "sadness": d5["sad"], "anger": d5["anger"],
                "neutral": d5["neutral"], "surprise": d5["surprise"],
                "fear": 0.0, "disgust": 0.0
            }
        except Exception:
            d5 = _heuristic(txt)
            return {
                "joy": d5["joy"], "sadness": d5["sad"], "anger": d5["anger"],
                "neutral": d5["neutral"], "surprise": d5["surprise"],
                "fear": 0.0, "disgust": 0.0
            }
    try:
        return _kobert_predict7(txt)
    except Exception as e:
        print("[kobert] load/forward failed:", e)
        try:
            d5 = _zeroshot_predict5(txt)
            return {
                "joy": d5["joy"], "sadness": d5["sad"], "anger": d5["anger"],
                "neutral": d5["neutral"], "surprise": d5["surprise"],
                "fear": 0.0, "disgust": 0.0
            }
        except Exception as e2:
            print("[kobert] zero-shot failed, fallback heuristic.", e2)
            d5 = _heuristic(txt)
            return {
                "joy": d5["joy"], "sadness": d5["sad"], "anger": d5["anger"],
                "neutral": d5["neutral"], "surprise": d5["surprise"],
                "fear": 0.0, "disgust": 0.0
            }


def predict(text: str) -> dict:
    try:
        d5 = _map7to5(predict7(text))
        s = sum(d5.values()) or 1.0
        return {k: v / s for k, v in d5.items()}
    except Exception:
        return _heuristic(text)


# ===== 세그먼트 평균 =====
def predict_segments(segments: list[dict]) -> dict:
    if not segments:
        return predict("")
    durs = [max(0.0, float(s.get("end", 0)) - float(s.get("start", 0))) for s in segments]
    total = sum(durs)
    if total <= 0:
        total = float(len(segments))
        durs = [1.0 for _ in segments]

    acc = {"joy": 0.0, "sad": 0.0, "anger": 0.0, "neutral": 0.0, "surprise": 0.0}
    for s, dur in zip(segments, durs):
        d = predict(s.get("text", ""))
        for k in acc:
            acc[k] += (dur / total) * d[k]
    return acc
