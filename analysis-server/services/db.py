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
# 🚫 Flask는 분석 전용 서버로 변경 → DB 테이블 생성 비활성화
# ==================================================================
def init_db():
    # is_mysql = _is_mysql()
    # # 분석 결과
    # ddl_mysql_results = """
    # CREATE TABLE IF NOT EXISTS analysis_results (
    #   id           INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    #   file_name    VARCHAR(255),
    #   type         VARCHAR(16),
    #   user_id      VARCHAR(64) DEFAULT 'anon',
    #   s3_key       VARCHAR(255),
    #   emotion      JSON,
    #   transcript   LONGTEXT,
    #   created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    # ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    # """
    # ddl_sqlite_results = """
    # CREATE TABLE IF NOT EXISTS analysis_results (
    #   id           INTEGER PRIMARY KEY AUTOINCREMENT,
    #   file_name    TEXT,
    #   type         TEXT,
    #   user_id      TEXT DEFAULT 'anon',
    #   s3_key       TEXT,
    #   emotion      TEXT,
    #   transcript   TEXT,
    #   created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    # );
    # """
    # # ✅ 메모 테이블
    # ddl_mysql_notes = """
    # CREATE TABLE IF NOT EXISTS emotion_notes (
    #   id         INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    #   user_id    VARCHAR(64) NOT NULL,
    #   note_date  DATE NOT NULL,
    #   content    TEXT,
    #   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    #   updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    #   UNIQUE KEY uq_note (user_id, note_date)
    # ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    # """
    # ddl_sqlite_notes = """
    # CREATE TABLE IF NOT EXISTS emotion_notes (
    #   id         INTEGER PRIMARY KEY AUTOINCREMENT,
    #   user_id    TEXT NOT NULL,
    #   note_date  TEXT NOT NULL,     -- 'YYYY-MM-DD'
    #   content    TEXT,
    #   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    #   updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    #   UNIQUE (user_id, note_date)
    # );
    # """
    # with engine.begin() as conn:
    #     conn.execute(text(ddl_mysql_results if is_mysql else ddl_sqlite_results))
    #     conn.execute(text(ddl_mysql_notes if is_mysql else ddl_sqlite_notes))
    log.info("[init_db disabled] Flask는 DB 테이블을 생성하지 않습니다.")
    return


# ==================================================================
# 🚫 분석 결과 저장 비활성화 (Node가 MySQL에 저장)
# ==================================================================
def save_analysis_result(file_type, file_name, emotion_obj, transcript="", user_id="anon", s3_key=None):
    # payload = json.dumps(emotion_obj, ensure_ascii=False)
    # is_mysql = _is_mysql()
    # q = text("""
    #     INSERT INTO analysis_results (file_name, type, user_id, s3_key, emotion, transcript)
    #     VALUES (:f, :t, :uid, :s3, CAST(:e AS JSON), :tr)
    # """) if is_mysql else text("""
    #     INSERT INTO analysis_results (file_name, type, user_id, s3_key, emotion, transcript)
    #     VALUES (:f, :t, :uid, :s3, :e, :tr)
    # """)
    # with engine.begin() as conn:
    #     conn.execute(q, {"f": file_name, "t": file_type, "uid": user_id, "s3": s3_key, "e": payload, "tr": transcript})
    log.info("[save_analysis_result disabled] Flask는 결과를 DB에 저장하지 않습니다.")
    return


# ==================================================================
# 🚫 조회 기능 (Node에서 담당)
# ==================================================================
# def get_recent_results(limit: int = 20):
#     q = text("""
#       SELECT id, file_name, type, user_id, s3_key,
#              JSON_EXTRACT(emotion, '$.fused.final_label') AS final_label,
#              created_at
#       FROM analysis_results
#       ORDER BY id DESC
#       LIMIT :lim
#     """) if _is_mysql() else text("""
#       SELECT id, file_name, type, user_id, s3_key, emotion, created_at
#       FROM analysis_results
#       ORDER BY id DESC
#       LIMIT :lim
#     """)
#     with engine.begin() as conn:
#         rows = conn.execute(q, {"lim": limit}).mappings().all()
#     return [dict(r) for r in rows]

# def get_results_by_day(day_str: str, user_id: str | None = None):
#     cond = "DATE(created_at) = :d"
#     params = {"d": day_str}
#     if user_id:
#         cond += " AND user_id = :uid"
#         params["uid"] = user_id
#     q = text(f"""
#       SELECT id, file_name, type, user_id, s3_key, emotion, created_at
#       FROM analysis_results
#       WHERE {cond}
#       ORDER BY id DESC
#     """)
#     with engine.begin() as conn:
#         rows = conn.execute(q, params).mappings().all()
#     return [dict(r) for r in rows]

# def get_results_in_range(start_date: str, end_date: str, user_id: str | None = None):
#     cond = "DATE(created_at) BETWEEN :s AND :e"
#     params = {"s": start_date, "e": end_date}
#     if user_id:
#         cond += " AND user_id = :uid"
#         params["uid"] = user_id
#     q = text(f"""
#       SELECT id, file_name, type, user_id, s3_key, emotion, created_at
#       FROM analysis_results
#       WHERE {cond}
#       ORDER BY created_at
#     """)
#     with engine.begin() as conn:
#         rows = conn.execute(q, params).mappings().all()
#     return [dict(r) for r in rows]


# ==================================================================
# 🚫 메모 기능 (Node로 이관)
# ==================================================================
# def upsert_note(user_id: str, note_date: str, content: str):
#     """user_id + YYYY-MM-DD 기준으로 UPSERT"""
#     if _is_mysql():
#         q = text("""
#           INSERT INTO emotion_notes (user_id, note_date, content)
#           VALUES (:uid, :d, :c)
#           ON DUPLICATE KEY UPDATE content = VALUES(content), updated_at = CURRENT_TIMESTAMP
#         """)
#     else:
#         q = text("""
#           INSERT INTO emotion_notes (user_id, note_date, content)
#           VALUES (:uid, :d, :c)
#           ON CONFLICT(user_id, note_date) DO UPDATE SET
#             content=excluded.content,
#             updated_at=CURRENT_TIMESTAMP
#         """)
#     with engine.begin() as conn:
#         conn.execute(q, {"uid": user_id, "d": note_date, "c": content})

# def get_note_by_day(user_id: str, note_date: str):
#     q = text("""
#       SELECT user_id, note_date, content, created_at, updated_at
#       FROM emotion_notes
#       WHERE user_id=:uid AND note_date=:d
#       LIMIT 1
#     """)
#     with engine.begin() as conn:
#         row = conn.execute(q, {"uid": user_id, "d": note_date}).mappings().first()
#     return dict(row) if row else None

# def get_notes_in_range(user_id: str, start_date: str, end_date: str):
#     q = text("""
#       SELECT user_id, note_date, content, updated_at
#       FROM emotion_notes
#       WHERE user_id=:uid AND note_date BETWEEN :s AND :e
#       ORDER BY note_date
#     """)
#     with engine.begin() as conn:
#         rows = conn.execute(q, {"uid": user_id, "s": start_date, "e": end_date}).mappings().all()
#     return [dict(r) for r in rows]
