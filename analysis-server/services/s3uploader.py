import os
import boto3
from concurrent.futures import ThreadPoolExecutor
from boto3.s3.transfer import TransferConfig
from botocore.exceptions import ClientError
from dotenv import load_dotenv

# 환경변수 로드
load_dotenv()

_AWS_REGION = os.getenv("AWS_REGION", "ap-northeast-2")
_S3_BUCKET = os.getenv("AWS_S3_BUCKET", "emotion-diary-videos")
_S3_PREFIX = os.getenv("S3_PREFIX", "videos/")  # or uploads/

_s3 = boto3.client(
    "s3",
    region_name=_AWS_REGION,
    aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
    aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
)
_pool = ThreadPoolExecutor(max_workers=2)

def _guess_ct(name: str) -> str:
    n = name.lower()
    if n.endswith(".mp4"): return "video/mp4"
    if n.endswith(".mov"): return "video/quicktime"
    if n.endswith(".mkv"): return "video/x-matroska"
    if n.endswith(".wav"): return "audio/wav"
    if n.endswith(".mp3"): return "audio/mpeg"
    if n.endswith(".m4a"): return "audio/mp4"
    if n.endswith(".jpg") or n.endswith(".jpeg"): return "image/jpeg"
    if n.endswith(".png"): return "image/png"
    return "application/octet-stream"

def _key_for(filename: str) -> str:
    return f"{_S3_PREFIX}{filename}"

def upload_async(local_path: str, filename: str) -> str:
    s3_key = _key_for(filename)
    cfg = TransferConfig(multipart_threshold=8*1024*1024, max_concurrency=4)

    def _run():
        try:
            print(f"S3 업로드 중... ({local_path} → s3://{_S3_BUCKET}/{s3_key})")
            _s3.upload_file(
                local_path, _S3_BUCKET, s3_key,
                ExtraArgs={"ContentType": _guess_ct(filename)},
                Config=cfg,
            )
            print(f"S3 업로드 완료: {s3_key}")
        except Exception as e:
            print(f"S3 업로드 실패: {e}")

    _pool.submit(_run)
    return s3_key

def download_from_s3(bucket, key, dest_dir="./uploads"):
    try:
        os.makedirs(dest_dir, exist_ok=True)
        filename = os.path.basename(key)
        local_path = os.path.join(dest_dir, f"tmp_{filename}")

        print(f"S3에서 다운로드 중... ({bucket}/{key} → {local_path})")
        _s3.download_file(bucket, key, local_path)
        print(f"S3 다운로드 완료: {local_path}")
        return local_path
    except ClientError as e:
        print(f"S3 다운로드 오류: {e}")
        return None

# app.py에서 부를 download()
def download(key):
    bucket = os.getenv("AWS_S3_BUCKET", _S3_BUCKET)
    return download_from_s3(bucket, key)
