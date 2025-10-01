🧪 Analysis Server (Flask, Python)
--------------실행방법----------------
cd analysis-server

# 가상환경 생성 (최초 1회만)
python -m venv venv

# 가상환경 활성화 (윈도우)
venv\Scripts\Activate.ps1

# 필요한 패키지 설치
pip install -r requirements.txt

# 서버 실행
python app.py
⚠️ 주의사항
절대 올리면 안 되는 폴더/파일

venv/ (가상환경)

venv310/ (로컬 테스트 환경)

uploads/ (사용자가 업로드한 파일)

__pycache__/ (파이썬 캐시파일)

.env (환경변수, API Key 들어감)

.vscode/ (개인 개발환경 설정)

→ 이미 .gitignore에 포함돼 있음, GitHub에 push 되면 안 됨.

처음 세팅할 때 반드시 pip install -r requirements.txt 실행
→ 안 하면 torch, transformers, opencv-python, deepface, flask 같은 라이브러리 안 깔려서 에러 남.

.env 파일 필요

API Key, 비밀번호 같은 민감정보는 .env에 넣어야 함.

.env는 GitHub에 올라가지 않으니까, 팀장이 따로 공유해야 함.

분석 처리 속도

Whisper, KoBERT, DeepFace 등 모델이 커서 실행이 느릴 수 있음.

로컬에서는 CPU만 사용하니 속도 느릴 수 있음 → 발표 시에는 서버/Colab/GPU 환경 고려.

테스트 시

Postman / cURL / Flutter 앱에서 http://localhost:5000/analyze/text 같은 엔드포인트 호출해서 확인.

✅ 설치 필수 (requirements.txt 안에 있음)
flask

flask-cors

torch

transformers

deepface

opencv-python

numpy

pandas

👉 정리하면:
venv → 활성화 → pip install -r requirements.txt → python app.py
이 흐름만 잘 지키면 문제 없음.
