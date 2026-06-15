#!/usr/bin/env python3
"""Volcengine Doubao speech flash transcription (URL or local file base64)."""

from __future__ import annotations

import argparse
import base64
import json
import sys
import uuid
import urllib.error
import urllib.request

FLASH_URL = "https://openspeech.bytedance.com/api/v3/auc/bigmodel/recognize/flash"
RESOURCE_ID = "volc.bigasr.auc_turbo"


def build_headers(api_key: str | None, app_key: str | None, access_key: str | None) -> dict:
    rid = str(uuid.uuid4())
    base = {
        "X-Api-Resource-Id": RESOURCE_ID,
        "X-Api-Request-Id": rid,
        "X-Api-Sequence": "-1",
        "Content-Type": "application/json",
    }
    if api_key:
        base["X-Api-Key"] = api_key
        return base
    if app_key and access_key:
        base["X-Api-App-Key"] = app_key
        base["X-Api-Access-Key"] = access_key
        return base
    raise ValueError("need volcengine api key or app_key+access_key")


def post_json(url: str, headers: dict, body: dict) -> tuple[dict, dict]:
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=600) as resp:
        hdrs = {k: v for k, v in resp.headers.items()}
        data = json.load(resp)
        return data, hdrs


def recognize(headers: dict, uid: str, audio_url: str | None, audio_file: str | None) -> str:
    if audio_url:
        audio = {"url": audio_url}
    elif audio_file:
        with open(audio_file, "rb") as f:
            audio = {"data": base64.b64encode(f.read()).decode("ascii")}
    else:
        raise ValueError("audio_url or audio_file required")

    body = {
        "user": {"uid": uid},
        "audio": audio,
        "request": {
            "model_name": "bigmodel",
            "enable_punc": True,
        },
    }
    data, hdrs = post_json(FLASH_URL, headers, body)
    code = hdrs.get("X-Api-Status-Code") or hdrs.get("x-api-status-code", "")
    if code and code != "20000000":
        raise RuntimeError(f"Doubao ASR failed: code={code} msg={hdrs.get('X-Api-Message', '')} body={data}")
    text = (data.get("result") or {}).get("text", "")
    if not text:
        raise ValueError(f"empty transcript: {json.dumps(data, ensure_ascii=False)[:500]}")
    return text.strip()


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--api-key", default="")
    p.add_argument("--app-key", default="")
    p.add_argument("--access-key", default="")
    p.add_argument("--audio-url", default="")
    p.add_argument("--audio-file", default="")
    p.add_argument("--output", required=True)
    args = p.parse_args()

    headers = build_headers(
        args.api_key or None,
        args.app_key or None,
        args.access_key or None,
    )
    uid = args.api_key or args.app_key or "xiaoyuzhou"

    print("==> Doubao flash recognize", file=sys.stderr)
    try:
        text = recognize(headers, uid, args.audio_url or None, args.audio_file or None)
    except Exception as e:
        if args.audio_url and args.audio_file:
            raise
        raise

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
