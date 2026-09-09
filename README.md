<div align="center">

<h1>마음.ZIP</h1>

<p><strong>표정과 말 속 감정을 기록하고 돌아보는 감정 분석 앱</strong></p>

<p>
사용자가 촬영한 영상의 음성에서 변환한 텍스트와 표정을 함께 분석하여<br>
감정 분포를 기록하고 피드백을 제공하는 모바일 애플리케이션입니다.
</p>

<p>
  <a href="#주요-기능">주요 기능</a>
  &nbsp;·&nbsp;
  <a href="#기술-스택">기술 스택</a>
  &nbsp;·&nbsp;
  <a href="#서비스-구조">서비스 구조</a>
  &nbsp;·&nbsp;
  <a href="#감정-분석-방식">감정 분석</a>
  &nbsp;·&nbsp;
  <a href="#로컬-실행">로컬 실행</a>
</p>

</div>

---

## 프로젝트 소개

마음.ZIP은 사용자가 촬영한 영상에서 **말한 내용과 표정을 함께 분석**하여 감정을 기록하고 돌아볼 수 있도록 만든 모바일 애플리케이션입니다.

영상의 음성은 **Whisper로 텍스트로 변환한 뒤 KoBERT로 감정을 분석**하고, 표정은 **DeepFace**를 이용해 분석합니다. 서로 다른 모델의 분석 결과를 공통 감정 체계로 정규화한 뒤 하나의 감정 분포로 결합합니다.

분석 결과와 메모는 날짜별로 관리하며, 캘린더와 주간 리포트를 통해 자신의 감정 흐름을 확인할 수 있도록 구성했습니다.

## 주요 기능

| 기능 | 설명 |
| --- | --- |
| **영상 감정 분석** | 촬영한 영상에서 말한 내용과 표정을 분석 |
| **멀티모달 감정 분석** | 텍스트와 표정 분석 결과를 결합해 최종 감정 분포 계산 |
| **AI 피드백** | 분석된 감정과 말한 내용을 바탕으로 감정 피드백 생성 |
| **활동 추천** | 주요 감정에 따라 일상에서 실천할 수 있는 활동 제안 |
| **감정 기록** | 분석 결과와 사용자가 작성한 메모 저장 |
| **감정 캘린더** | 날짜별 대표 감정과 기록 확인 |
| **주간 리포트** | 기간별 감정 분포와 감정 흐름 확인 |
| **감정 대화** | 현재 감정을 바탕으로 AI와 대화 |

### 사용 흐름

1. 앱에서 영상을 촬영합니다.
2. 영상을 업로드하고 AI 분석을 요청합니다.
3. 영상에서 말한 내용과 표정을 각각 분석합니다.
4. 두 분석 결과를 결합해 최종 감정 분포를 계산합니다.
5. 감정 결과와 AI 피드백을 확인합니다.
6. 결과를 날짜별로 기록하고 캘린더와 주간 리포트에서 확인합니다.

## 기술 스택

### Mobile

<p>
  <img src="https://img.shields.io/badge/Flutter-F3F4F6?style=for-the-badge&amp;logo=flutter&amp;logoColor=02569B" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-F3F4F6?style=for-the-badge&amp;logo=dart&amp;logoColor=0175C2" alt="Dart" />
</p>

영상 촬영·업로드 · 감정 결과 시각화 · 캘린더·주간 리포트

### Backend

<p>
  <img src="https://img.shields.io/badge/Node.js-F3F4F6?style=for-the-badge&amp;logo=nodedotjs&amp;logoColor=339933" alt="Node.js" />
  <img src="https://img.shields.io/badge/Express-F3F4F6?style=for-the-badge&amp;logo=express&amp;logoColor=000000" alt="Express" />
  <img src="https://img.shields.io/badge/Python-F3F4F6?style=for-the-badge&amp;logo=python&amp;logoColor=3776AB" alt="Python" />
  <img src="https://img.shields.io/badge/Flask-F3F4F6?style=for-the-badge&amp;logo=flask&amp;logoColor=000000" alt="Flask" />
</p>

Node.js / Express 기반 서비스 API · Python / Flask 기반 AI 분석 서버

### AI Models & API

<p>
  <img src="https://img.shields.io/badge/Whisper-F3F4F6?style=for-the-badge" alt="Whisper" />
  <img src="https://img.shields.io/badge/KoBERT-F3F4F6?style=for-the-badge" alt="KoBERT" />
  <img src="https://img.shields.io/badge/DeepFace-F3F4F6?style=for-the-badge" alt="DeepFace" />
  <img src="https://img.shields.io/badge/OpenAI_API-F3F4F6?style=for-the-badge" alt="OpenAI API" />
</p>

| 기술 | 용도 |
| --- | --- |
| Whisper | 영상 속 음성을 텍스트로 변환 |
| KoBERT | 변환된 텍스트의 감정 분석 |
| DeepFace | 영상 프레임의 표정 감정 분석 |
| OpenAI API | 분석 결과와 텍스트를 바탕으로 피드백 생성 |

### Database & Storage

<p>
  <img src="https://img.shields.io/badge/MySQL-F3F4F6?style=for-the-badge&amp;logo=mysql&amp;logoColor=4479A1" alt="MySQL" />
  <img src="https://img.shields.io/badge/AWS_S3-F3F4F6?style=for-the-badge" alt="AWS S3" />
</p>

MySQL 기반 감정 결과·메모 저장 · AWS S3 기반 영상 파일 저장

### Communication

REST API · JSON · Multipart

## 서비스 구조

```mermaid
flowchart TD
    Flutter["Flutter App"] -->|"영상 업로드·분석 요청"| Node["Node.js Main Server"]
    Node -->|"영상 저장"| S3[("AWS S3")]
    Node -->|"s3Key로 분석 요청"| Flask["Flask AI Server"]
    Flask -->|"영상 다운로드"| S3
    Flask -->|"피드백 생성 요청"| GPT["OpenAI API"]
    GPT -->|"피드백 반환"| Flask
    Flask -->|"분석 결과 반환"| Node
    Node -->|"분석 결과 저장"| DB[("MySQL")]
    Node -->|"결과 응답"| Flutter
```

### 서버별 역할

| 구성 | 역할 |
| --- | --- |
| **Flutter** | 영상 촬영·업로드, 분석 요청, 결과·캘린더·리포트 UI |
| **Node.js** | API 처리, 영상 업로드, S3 연동, 분석 요청 중계, MySQL 저장 |
| **Flask** | 영상 전처리, Whisper·KoBERT·DeepFace 실행, 감정 결합, AI 피드백 생성 |
| **AWS S3** | 업로드된 영상 파일 저장 |
| **MySQL** | 감정 분석 결과, 메모 등 서비스 데이터 저장 |

영상 **업로드와 AI 분석을 별도의 요청으로 분리**했습니다.

먼저 Node.js가 영상을 S3에 저장하고 `media_id`와 `s3Key`를 반환합니다. 이후 분석 요청에서 해당 `s3Key`를 Flask에 전달하고, Flask가 S3에서 영상을 내려받아 AI 분석을 수행합니다.

## 감정 분석 방식

영상 하나에서 **말한 내용과 표정이라는 두 종류의 정보**를 추출하여 각각 분석합니다.

```mermaid
flowchart TD
    Video["영상"] --> Audio["오디오 추출"]
    Video --> Frame["프레임 추출"]
    Audio --> Whisper["Whisper · 음성을 텍스트로 변환"]
    Whisper --> KoBERT["KoBERT · 텍스트 감정 분석"]
    Frame --> DeepFace["DeepFace · 표정 감정 분석"]
    KoBERT --> Normalize["공통 5개 감정으로 정규화"]
    DeepFace --> Normalize
    Normalize --> Fusion["텍스트·표정 분포 결합"]
    Fusion --> Result["최종 감정 분포"]
```

### 1. 음성을 텍스트로 변환

영상에서 오디오를 추출하고 Whisper를 이용해 음성을 텍스트로 변환합니다.

변환된 텍스트와 각 구간의 시간 정보를 텍스트 감정 분석에 사용합니다.

### 2. 텍스트 감정 분석

Whisper가 생성한 텍스트 구간을 KoBERT로 분석합니다.

전체 문장을 한 번만 분류하는 대신 **구간별 감정을 분석하고 구간 길이를 반영하여 전체 텍스트 감정 분포를 계산**합니다.

### 3. 표정 감정 분석

DeepFace를 이용해 영상 프레임에서 표정 감정을 분석합니다.

모든 영상 프레임을 처리하지 않고 **0.5초 간격으로 최대 180프레임**을 분석하도록 제한했습니다.

각 프레임은 동일하게 반영하지 않고 **얼굴 영역 크기와 프레임 선명도**를 이용해 가중치를 적용합니다. 얼굴이 작거나 흐릿하게 촬영된 프레임이 최종 결과에 미치는 영향을 줄이도록 구성했습니다.

### 4. 감정 체계 정규화

KoBERT와 DeepFace는 서로 다른 감정 분류 체계를 사용하기 때문에 분석 결과를 바로 결합할 수 없습니다.

두 모델의 출력을 다음 5개 감정으로 변환하여 사용합니다.

| 공통 감정 | 의미 |
| --- | --- |
| `joy` | 기쁨 |
| `sad` | 슬픔 |
| `anger` | 분노 |
| `neutral` | 중립 |
| `surprise` | 놀람 |

일부 감정은 프로젝트의 공통 감정 체계에 맞게 다음과 같이 매핑합니다.

| 모델 감정 | 공통 감정 |
| --- | --- |
| `happy` | `joy` |
| `fear` | `sad` |
| `disgust` | `anger` |

이 매핑은 서로 다른 모델의 출력을 결합하기 위한 프로젝트 내 처리 기준입니다. 변환된 분포는 다시 정규화한 뒤 사용합니다.

### 5. 멀티모달 감정 결합

텍스트와 표정 분석 결과를 하나의 최종 감정 분포로 결합합니다.

기본 결합 비율은 다음과 같습니다.

```text
최종 감정 분포
= 텍스트 감정 분포 × 0.7
+ 표정 감정 분포 × 0.3
```

| 분석 정보 | 기본 가중치 |
| --- | ---: |
| 텍스트 감정 | 70% |
| 표정 감정 | 30% |

말한 내용을 주요 감정 정보로 사용하면서 표정 정보를 함께 반영하도록 구성했습니다.

분석 신뢰도가 낮거나 두 분석 결과가 크게 충돌하는 경우를 판단하기 위한 처리 로직도 포함했습니다.

## AI 피드백

최종 감정 분포와 영상에서 말한 내용을 바탕으로 사용자에게 감정 피드백을 제공합니다.

| 입력 | 처리 | 출력 |
| --- | --- | --- |
| 감정 분포·음성에서 변환한 텍스트 | OpenAI API | 감정 피드백·활동 추천 |

**KoBERT와 DeepFace는 감정 분석**, **OpenAI API는 분석 결과를 설명하는 피드백 생성**에 활용합니다. Whisper는 음성을 텍스트로 변환하는 역할을 담당합니다.

## 감정 데이터 관리

분석 결과는 Node.js를 통해 MySQL에 저장합니다.

| 데이터 | 내용 |
| --- | --- |
| 감정 분포 | 기쁨·슬픔·분노·중립·놀람의 비율 |
| 대표 감정 | 분석 결과 중 주요 감정 |
| AI 피드백 | 감정 결과를 기반으로 생성된 피드백 |
| 활동 추천 | 감정에 따른 활동 |
| 메모 | 사용자가 직접 작성한 감정 기록 |
| 생성 시각 | 분석 결과 생성 시간 |

하루에 여러 분석 결과가 생성될 수 있기 때문에 날짜별 대표 결과를 조회할 때는 **`created_at`을 기준으로 가장 최근 분석 결과**를 사용하도록 구성했습니다.

이를 통해 감정 캘린더와 리포트에서 사용할 날짜별 대표 데이터의 기준을 일관되게 유지합니다.

## 주요 구현 포인트

| 항목 | 설명 |
| --- | --- |
| **영상 분석량 제어** | 표정 분석 대상을 0.5초 간격·최대 180프레임으로 제한 |
| **프레임 품질 반영** | 얼굴 영역 크기와 선명도를 기준으로 프레임별 가중치 적용 |
| **모델별 감정 체계 통합** | 서로 다른 감정 라벨을 공통 5개 감정으로 매핑하고 정규화 |
| **서비스·분석 서버 분리** | Node.js는 서비스 API와 저장, Flask는 AI 분석 담당 |
| **API 응답 구조 정리** | Flask 분석 결과를 Node.js 서비스 응답으로 정리하고 Flutter 화면 모델에 매핑 |

<details>
<summary>API 응답 구조를 정리한 배경</summary>

개발 과정에서 Flask의 분석은 정상적으로 완료됐지만 Flutter에서는 모든 감정 비율이 0%로 표시되는 문제가 있었습니다.

서버별 응답을 확인해 데이터 참조 구조의 차이를 찾고, Node.js에서 분석 결과를 서비스 응답 형태로 정리한 뒤 Flutter에서 화면 모델로 변환하도록 수정했습니다.

</details>

## 프로젝트 구성

| 경로 | 내용 |
| --- | --- |
| `frontend/` | Flutter 애플리케이션 및 서버 API 연동 |
| `main-server/` | Node.js API, S3·MySQL 연동 |
| `analysis-server/` | Flask 기반 AI 분석 서버 |
| `analysis-server/app.py` | Flask 애플리케이션 |
| `analysis-server/services/stt.py` | Whisper 음성 인식 |
| `analysis-server/services/kobert.py` | 텍스트 감정 분석 |
| `analysis-server/services/vision.py` | 영상 표정 분석 |
| `analysis-server/services/fusion.py` | 텍스트·표정 결과 결합 |
| `analysis-server/services/gpt.py` | AI 피드백 생성 |

## 로컬 실행

Python, Node.js·npm, Flutter SDK, MySQL이 필요합니다.

AWS S3, OpenAI API, DB 접속 정보와 서버 주소 등 필요한 설정을 준비한 뒤 각 서버와 앱을 실행합니다. 아래 명령은 각 터미널이 저장소 루트에 있는 상태에서 시작합니다.

### 1. Flask AI 서버

Python 가상환경을 생성합니다.

```bash
cd analysis-server
python -m venv venv
```

Windows PowerShell에서 가상환경을 활성화하고 실행합니다.

```powershell
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
python app.py
```

기본 포트는 `5001`입니다.

<details>
<summary>macOS / Linux</summary>

```bash
cd analysis-server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py
```

</details>

### 2. Node.js 메인 서버

별도 터미널에서 실행합니다.

```bash
cd main-server
npm install
npm start
```

기본 포트는 `3000`입니다.

MySQL, AWS S3, Flask 서버 주소 등 필요한 환경변수를 설정해야 합니다.

### 3. Flutter 앱

별도 터미널에서 실행합니다.

```bash
cd frontend
flutter pub get
flutter run
```

앱의 서버 주소는 실행 환경에 맞게 설정합니다.

| 실행 환경 | 개발 PC의 서버 접근 주소 |
| --- | --- |
| Android Emulator | `10.0.2.2` |
| 실기기 | 개발 PC의 네트워크 IP 주소 |

예를 들어 Android Emulator에서 Node.js 메인 서버에 접근하는 주소는 `http://10.0.2.2:3000`입니다.

실기기에서 실행할 때는 개발 PC와 기기가 서로 통신할 수 있는 네트워크에 연결되어 있어야 합니다.

## 프로젝트 정보

| 항목 | 내용 |
| --- | --- |
| 개발 기간 | 2025.05 ~ 2025.11 |
| 형태 | 팀 프로젝트 |
| 플랫폼 | Android / Flutter |
| 주요 분야 | 모바일 · 백엔드 · AI 분석 |

---

<div align="center">

<p><strong>마음.ZIP</strong></p>
<p>감정을 분석하고, 기록하고, 다시 돌아볼 수 있도록.</p>

</div>
