# services/kobert.py
# KoBERT 기반 한국어 감정 분석
# - 7감정 분류 모델 사용 (jason9693/kobert-emotion-classification)
# - 5감정 매핑(joy,sad,anger,neutral,surprise)
# - 기본 비활성화(제로샷/휴리스틱로 대체) — 환경변수 KOBERT_DISABLE=0 으로 활성화


import os, re
import torch

LABELS7 = ["anger","disgust","fear","joy","neutral","sadness","surprise"]
LABELS5 = ["joy","sad","anger","neutral","surprise"]

_MODEL_ID = os.getenv("KOBERT_EMO_ID", "jason9693/kobert-emotion-classification")
_DISABLE = os.getenv("KOBERT_DISABLE", "1") == "1"  # 기본 비활성화(제로샷/휴리스틱로)
_tokenizer = None
_model = None
_device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

_POS = ["기쁘","좋아","행복","즐겁","재밌","감사"]
_NEG_SAD = ["슬프","우울","눈물","힘들","외롭","서운"]
_NEG_ANG = ["화나","짜증","분노","빡치","열받","화났"]
_SURP   = ["깜짝","놀랐","놀라","헉","예상 못"]

def _dist5(joy=0, sad=0, anger=0, neutral=1.0, surprise=0):
    s = joy+sad+anger+neutral+surprise
    if s <= 0: return {"joy":0,"sad":0,"anger":0,"neutral":1.0,"surprise":0}
    return { "joy":joy/s, "sad":sad/s, "anger":anger/s, "neutral":neutral/s, "surprise":surprise/s }

def _heuristic(text:str)->dict:
    t = (text or "").lower()
    if not t: return _dist5()
    score = {"joy":0.0,"sad":0.0,"anger":0.0,"neutral":0.0,"surprise":0.0}
    def hit(ws): return any(re.search(w, t) for w in ws)
    if hit(_POS): score["joy"] += 1.0
    if hit(_NEG_SAD): score["sad"] += 1.0
    if hit(_NEG_ANG): score["anger"] += 1.0
    if hit(_SURP): score["surprise"] += 0.8
    if sum(score.values()) == 0: score["neutral"] = 1.0
    return _dist5(**score)

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

def _map7to5(d7: dict) -> dict:
    return {
        "joy":      float(d7.get("joy",0.0)),
        "sad":      float(d7.get("sadness",0.0)) + float(d7.get("fear",0.0)),
        "anger":    float(d7.get("anger",0.0)) + float(d7.get("disgust",0.0)),
        "neutral":  float(d7.get("neutral",0.0)),
        "surprise": float(d7.get("surprise",0.0)),
    }

def _kobert_predict7(text: str) -> dict:
    tok, mdl = _load_kobert()
    with torch.no_grad():
        inputs = tok((text or "").strip(), truncation=True, padding=True, max_length=128, return_tensors="pt").to(_device)
        logits = mdl(**inputs).logits
        probs = _softmax(logits)[0].cpu().tolist()
    return {lab: float(p) for lab, p in zip(LABELS7, probs)}

_zero = None
def _load_zeroshot():
    global _zero
    if _zero is None:
        from transformers import pipeline
        _zero = pipeline("zero-shot-classification", model="joeddav/xlm-roberta-large-xnli",
                         device=0 if torch.cuda.is_available() else -1)
    return _zero

def _zeroshot_predict5(text: str) -> dict:
    z = _load_zeroshot()
    labels = ["joy","sad","anger","neutral","surprise"]
    res = z((text or "").strip(), candidate_labels=labels,
            hypothesis_template="이 문장의 감정은 {} 이다.", multi_label=True)
    scores = {lbl: float(sc) for lbl, sc in zip(res["labels"], res["scores"])}
    total = sum(scores.values()) or 1.0
    return {k: scores.get(k,0.0)/total for k in labels}

def predict7(text: str) -> dict:
    txt = (text or "").strip()
    if not txt:
        return {"anger":0.0,"disgust":0.0,"fear":0.0,"joy":0.0,"neutral":1.0,"sadness":0.0,"surprise":0.0}
    if _DISABLE:
        try:
            d5 = _zeroshot_predict5(txt)
            return {"joy":d5["joy"],"sadness":d5["sad"],"anger":d5["anger"],"neutral":d5["neutral"],
                    "surprise":d5["surprise"],"fear":0.0,"disgust":0.0}
        except Exception:
            d5 = _heuristic(txt)
            return {"joy":d5["joy"],"sadness":d5["sad"],"anger":d5["anger"],"neutral":d5["neutral"],
                    "surprise":d5["surprise"],"fear":0.0,"disgust":0.0}
    try:
        return _kobert_predict7(txt)
    except Exception as e:
        print("[kobert] load/forward failed, fallback to zero-shot. err:", e)
        try:
            d5 = _zeroshot_predict5(txt)
            return {"joy":d5["joy"],"sadness":d5["sad"],"anger":d5["anger"],"neutral":d5["neutral"],
                    "surprise":d5["surprise"],"fear":0.0,"disgust":0.0}
        except Exception as e2:
            print("[kobert] zero-shot failed, fallback to heuristic.", e2)
            d5 = _heuristic(txt)
            return {"joy":d5["joy"],"sadness":d5["sad"],"anger":d5["anger"],"neutral":d5["neutral"],
                    "surprise":d5["surprise"],"fear":0.0,"disgust":0.0}

def predict(text: str) -> dict:
    try:
        d5 = _map7to5(predict7(text))
        s = sum(d5.values()) or 1.0
        return {k: v/s for k,v in d5.items()}
    except Exception:
        return _heuristic(text)

def predict_segments(segments: list[dict]) -> dict:
    """
    세그먼트 길이(초) 가중 평균
    """
    if not segments:
        return predict("")
    durs = [max(0.0, float(s.get("end",0)) - float(s.get("start",0))) for s in segments]
    total = sum(durs)
    if total <= 0:
        total = float(len(segments))
        durs = [1.0 for _ in segments]

    acc = {"joy":0.0,"sad":0.0,"anger":0.0,"neutral":0.0,"surprise":0.0}
    for s, dur in zip(segments, durs):
        d = predict(s.get("text",""))
        for k in acc:
            acc[k] += (dur/total) * d[k]
    return acc
