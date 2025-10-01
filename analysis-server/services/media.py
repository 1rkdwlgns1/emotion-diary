import os, subprocess, shlex, tempfile

AUDIO_PREPROCESS = os.getenv("AUDIO_PREPROCESS", "light").lower().strip()
# 옵션: none | light | aggressive
# - none: 원본 그대로 (전처리 없음)
# - light(기본): high/lowpass + dynaudnorm (무음 제거 없음)
# - aggressive: light + silenceremove (긴 무음만 제거, 완화된 파라미터)

def _run(cmd: str):
    p = subprocess.run(shlex.split(cmd), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return p.returncode, p.stdout.strip(), p.stderr.strip()

def has_audio(video_path: str) -> bool:
    cmd = f'ffprobe -v error -select_streams a:0 -show_entries stream=codec_type -of csv=p=0 "{video_path}"'
    code, out, _ = _run(cmd)
    return (code == 0) and ('audio' in (out or '').lower())

def extract_wav(video_path: str, out_dir: str | None = None, sr: int = 16000) -> str | None:
    out_dir = out_dir or tempfile.gettempdir()
    base = os.path.splitext(os.path.basename(video_path))[0]
    out_wav = os.path.join(out_dir, f"{base}_mono{sr}.wav")
    cmd = f'ffmpeg -y -i "{video_path}" -vn -ac 1 -ar {sr} -f wav "{out_wav}"'
    code, _, err = _run(cmd)
    if code == 0 and os.path.exists(out_wav):
        cleaned = preprocess_wav(out_wav, sr=sr)
        return cleaned or out_wav
    print("[media.extract_wav] ffmpeg failed:", err)
    return None

def _build_af_chain(sr: int) -> str:
    base = "highpass=f=100,lowpass=f=8000,dynaudnorm=f=150:g=31"
    if AUDIO_PREPROCESS == "none":
        return f"aresample={sr}"
    if AUDIO_PREPROCESS == "light":
        return base
    # aggressive: 무음 제거(매우 완화) 추가 — 긴 정적만 자름
    # threshold 낮추고, 필요한 무음 길이를 길게 잡아 발화가 잘리지 않게 조정
    sil = (
        "silenceremove="
        "start_periods=1:start_silence=1.2:start_threshold=-45dB:"
        "stop_periods=1:stop_silence=1.5:stop_threshold=-45dB"
    )
    return f"{base},{sil}"

def preprocess_wav(wav_path: str, sr: int = 16000) -> str | None:
    if AUDIO_PREPROCESS == "none":
        return wav_path
    out = os.path.splitext(wav_path)[0] + "_clean.wav"
    af = _build_af_chain(sr)
    cmd = f'ffmpeg -y -i "{wav_path}" -ac 1 -ar {sr} -af "{af}" "{out}"'
    code, _, err = _run(cmd)
    if code == 0 and os.path.exists(out):
        return out
    print("[media.preprocess_wav] ffmpeg failed:", err)
    return None
