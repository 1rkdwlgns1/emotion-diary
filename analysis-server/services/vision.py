#Face API 자리

# services/vision.py
import os
import requests
from config import AZURE_FACE_ENDPOINT, AZURE_FACE_KEY

def analyze(image_path: str) -> dict:
    """
    이미지에서 얼굴의 emotion 추정 (Azure Face API)
    반환: {"emotion": "...", "scores": {...}, "faces": [...]} 형태
    얼굴이 없으면 {"emotion": "neutral", "scores": {}, "faces": []}
    """
    if not (AZURE_FACE_ENDPOINT and AZURE_FACE_KEY):
        # 키가 아직 없으면 mock 반환
        return {"emotion": "neutral", "scores": {}, "faces": []}

    url = f"{AZURE_FACE_ENDPOINT}/face/v1.0/detect"
    params = {
        "returnFaceAttributes": "emotion",
        # 필요 시 "returnFaceId": "true", "detectionModel": "detection_03" 등 옵션 추가
    }
    headers = {
        "Ocp-Apim-Subscription-Key": AZURE_FACE_KEY,
        "Content-Type": "application/octet-stream",
    }

    with open(image_path, "rb") as f:
        data = f.read()

    try:
        r = requests.post(url, params=params, headers=headers, data=data, timeout=15)
        r.raise_for_status()
        faces = r.json()  # [{faceAttributes: {emotion: {...}}}, ...]
        if not faces:
            return {"emotion": "neutral", "scores": {}, "faces": []}

        # 여러 얼굴일 경우 첫 번째만 사용(원하면 평균/최댓값으로 확장 가능)
        emo = faces[0].get("faceAttributes", {}).get("emotion", {})
        if not emo:
            return {"emotion": "neutral", "scores": {}, "faces": faces}

        top = max(emo, key=emo.get)
        return {"emotion": top, "scores": emo, "faces": faces}
    except Exception as e:
        print("[AzureFace] error:", e)
        return {"emotion": "neutral", "scores": {}, "faces": [], "error": str(e)}
