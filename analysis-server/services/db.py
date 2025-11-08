import os, json, logging
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()

log = logging.getLogger("analysis-server")
if not log.handlers:
    log.addHandler(logging.StreamHandler())
log.setLevel(logging.INFO)

DB_URL = os.getenv("DB_URL", "sqlite:///db/analysis_results.db")
log.info(f"DB_URL in use: {DB_URL}")

engine = create_engine(
    DB_URL,
    echo=False,
    future=True,
    pool_pre_ping=True,
    pool_recycle=1800,
    pool_timeout=30,
    connect_args={"check_same_thread": False} if DB_URL.startswith("sqlite") else {},
)

def _is_mysql() -> bool:
    try:
        return engine.dialect.name.lower().startswith("mysql")
    except Exception:
        return False


# ==================================================================
# ✅ Flask 주간 리포트용 범위 조회 함수 (날짜 필터 수정 완료)
# ==================================================================
def get_results_in_range(user_id: str, start_date: str, end_date: str):
    """Node → Flask 주간 리포트용: 특정 유저의 감정 결과 조회"""
    try:
        q = text("""
            SELECT emotion_detail, emotion, created_at
            FROM analysis_results
            WHERE user_id = :uid
              AND created_at BETWEEN :s AND DATE_ADD(:e, INTERVAL 1 DAY)
            ORDER BY created_at ASC
        """)
        with engine.begin() as conn:
            rows = conn.execute(q, {"uid": user_id, "s": start_date, "e": end_date}).mappings().all()

        result = []
        for r in rows:
            # ✅ emotion_detail 또는 emotion 중 있는 값 사용
            emo_raw = r.get("emotion_detail") or r.get("emotion")
            if isinstance(emo_raw, str):
                try:
                    emo = json.loads(emo_raw)
                except Exception:
                    emo = {}
            elif isinstance(emo_raw, dict):
                emo = emo_raw
            else:
                emo = {}

            result.append({
                "emotion_detail": emo,
                "created_at": r.get("created_at")
            })

        return result
    except Exception as e:
        log.error(f"❌ get_results_in_range 오류: {e}")
        return []


# ==================================================================
# 🚫 Flask는 분석 전용 서버로 변경 → DB 테이블 생성 비활성화
# ==================================================================
def init_db():
    log.info("[init_db disabled] Flask는 DB 테이블을 생성하지 않습니다.")
    return


# ==================================================================
# 🚫 분석 결과 저장 비활성화 (Node가 MySQL에 저장)
# ==================================================================
def save_analysis_result(file_type, file_name, emotion_obj, transcript="", user_id="anon", s3_key=None):
    log.info("[save_analysis_result disabled] Flask는 결과를 DB에 저장하지 않습니다.")
    return
