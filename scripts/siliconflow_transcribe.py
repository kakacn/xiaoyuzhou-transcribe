#!/usr/bin/env python3
"""SiliconFlow audio transcription (multipart upload)."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

API_URL = "https://api.siliconflow.cn/v1/audio/transcriptions"
MAX_BYTES = 24 * 1024 * 1024  # stay under typical limits


def transcribe_file(api_key: str, model: str, path: str) -> str:
    boundary = f"----xyboundary{os.getpid()}"
    with open(path, "rb") as f:
        audio = f.read()

    body = []
    for name, val in (("model", model),):
        body.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{val}\r\n")
    body.append(
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.mp3\"\r\n"
        f"Content-Type: audio/mpeg\r\n\r\n"
    )
    payload = "".join(body).encode("utf-8") + audio + f"\r\n--{boundary}--\r\n".encode("utf-8")

    req = urllib.request.Request(
        API_URL,
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=600) as resp:
        data = json.load(resp)
    text = data.get("text", "")
    if not text:
        raise ValueError(f"empty transcript: {data}")
    return text.strip()


def ffprobe_duration(path: str) -> float:
    out = subprocess.check_output(
        ["ffprobe", "-v", "quiet", "-show_entries", "format=duration", "-of", "csv=p=0", path],
        text=True,
    )
    return float(out.strip())


def split_mp3(path: str, tmpdir: str) -> list[str]:
    size = os.path.getsize(path)
    if size <= MAX_BYTES:
        return [path]
    dur = ffprobe_duration(path)
    n = (size // MAX_BYTES) + 1
    chunk_dur = dur / n + 5
    parts = []
    for i in range(n):
        out = os.path.join(tmpdir, f"chunk_{i}.mp3")
        start = i * chunk_dur
        subprocess.run(
            ["ffmpeg", "-y", "-i", path, "-ss", str(start), "-t", str(chunk_dur), "-c", "copy", out],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True,
        )
        parts.append(out)
    return parts


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--api-key", required=True)
    p.add_argument("--audio-file", required=True)
    p.add_argument("--model", default="FunAudioLLM/SenseVoiceSmall")
    p.add_argument("--output", required=True)
    args = p.parse_args()

    print(f"==> SiliconFlow model={args.model}", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp:
        chunks = split_mp3(args.audio_file, tmp)
        texts = []
        for i, ch in enumerate(chunks):
            print(f"    chunk {i+1}/{len(chunks)}...", file=sys.stderr)
            texts.append(transcribe_file(args.api_key, args.model, ch))
    text = "\n".join(texts)
    with open(args.output, "w", encoding="utf-8") as f:
        f.write(text + "\n")
    print(f"    chars={len(text)}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        raise SystemExit(1)
