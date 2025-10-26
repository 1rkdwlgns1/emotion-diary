# services/db.py
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

engine = create_engine(DB_URL, echo=False, future=True, pool_pre_ping=True)

def _is_mysql() -> bool:
    try:
        return engine.dialect.name.lower().startswith("mysql")
    except Exception:
        return False

def init_db():
    """DB 종류에 맞게 테이블 생성"""
    is_mysql = _is_mysql()
    ddl_mysql = """
    CREATE TABLE IF NOT EXISTS analysis_results (
      id           INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
      file_name    VARCHAR(255),
      type         VARCHAR(16),       -- text/image/audio/video
      user_id      VARCHAR(64) DEFAULT 'anon',
      s3_key       VARCHAR(255),
      emotion      JSON,              -- 전체 결과 JSON
      transcript   LONGTEXT,
      created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    """
    ddl_sqlite = """
    CREATE TABLE IF NOT EXISTS analysis_results (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      file_name    TEXT,
      type         TEXT,              -- text/image/audio/video
      user_id      TEXT DEFAULT 'anon',
      s3_key       TEXT,
      emotion      TEXT,              -- JSON 문자열
      transcript   TEXT,
      created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """
    with engine.begin() as conn:
        conn.execute(text(ddl_mysql if is_mysql else ddl_sqlite))

def save_analysis_result(
    file_type: str,
    file_name: str,
    emotion_obj,
    transcript: str = "",
    user_id: str = "anon",
    s3_key: str | None = None,
):
    """분석 1건 저장 (MySQL/SQLite 분기)"""
    payload = json.dumps(emotion_obj, ensure_ascii=False)
    is_mysql = _is_mysql()
    if is_mysql:
        q = text("""
            INSERT INTO analysis_results (file_name, type, user_id, s3_key, emotion, transcript)
            VALUES (:f, :t, :uid, :s3, CAST(:e AS JSON), :tr)
        """)
    else:
        q = text("""
            INSERT INTO analysis_results (file_name, type, user_id, s3_key, emotion, transcript)
            VALUES (:f, :t, :uid, :s3, :e, :tr)
        """)
    with engine.begin() as conn:
        conn.execute(q, {"f": file_name, "t": file_type, "uid": user_id, "s3": s3_key, "e": payload, "tr": transcript})

# -------------------- 조회용 --------------------

def get_recent_results(limit: int = 20):
    q = text("""
      SELECT id, file_name, type, user_id, s3_key,
             JSON_EXTRACT(emotion, '$.fused.final_label') AS final_label,
             created_at
      FROM analysis_results
      ORDER BY id DESC
      LIMIT :lim
    """) if _is_mysql() else text("""
      SELECT id, file_name, type, user_id, s3_key, emotion, created_at
      FROM analysis_results
      ORDER BY id DESC
      LIMIT :lim
    """)
    with engine.begin() as conn:
        rows = conn.execute(q, {"lim": limit}).mappings().all()
    return [dict(r) for r in rows]

def get_results_by_day(day_str: str, user_id: str | None = None):
    cond = "DATE(created_at) = :d"
    params = {"d": day_str}
    if user_id:
        cond += " AND user_id = :uid"
        params["uid"] = user_id
    q = text(f"""
      SELECT id, file_name, type, user_id, s3_key, emotion, created_at
      FROM analysis_results
      WHERE {cond}
      ORDER BY id DESC
    """)
    with engine.begin() as conn:
        rows = conn.execute(q, params).mappings().all()
    return [dict(r) for r in rows]

def get_results_in_range(start_date: str, end_date: str, user_id: str | None = None):
    cond = "DATE(created_at) BETWEEN :s AND :e"
    params = {"s": start_date, "e": end_date}
    if user_id:
        cond += " AND user_id = :uid"
        params["uid"] = user_id
    q = text(f"""
      SELECT id, file_name, type, user_id, s3_key, emotion, created_at
      FROM analysis_results
      WHERE {cond}
      ORDER BY created_at
    """)
    with engine.begin() as conn:
        rows = conn.execute(q, params).mappings().all()
    return [dict(r) for r in rows]
