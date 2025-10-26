# services/s3uploader.py
import os
import boto3
from concurrent.futures import ThreadPoolExecutor
from boto3.s3.transfer import TransferConfig

_AWS_REGION = os.getenv("AWS_REGION", "ap-northeast-2")
_S3_BUCKET  = os.getenv("S3_BUCKET", "your-bucket-name")
_S3_PREFIX  = os.getenv("S3_PREFIX", "uploads/")

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
    """S3 비동기 업로드. 즉시 s3_key 반환."""
    s3_key = _key_for(filename)
    cfg = TransferConfig(multipart_threshold=8*1024*1024, max_concurrency=4)

    def _run():
        _s3.upload_file(
            local_path, _S3_BUCKET, s3_key,
            ExtraArgs={"ContentType": _guess_ct(filename)},
            Config=cfg,
        )
        # 파일 업로드 완료 후, 필요하면 여기서 cleanup도 가능

    _pool.submit(_run)
    return s3_key
