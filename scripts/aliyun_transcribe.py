#!/usr/bin/env python3
"""DashScope (Aliyun Bailian) async file transcription for public audio URLs."""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request

SUBMIT_URL = "https://dashscope.aliyuncs.com/api/v1/services/audio/asr/transcription"
TASK_URL = "https://dashscope.aliyuncs.com/api/v1/tasks/{task_id}"


def api_request(method: str, url: str, api_key: str, body: dict | None = None) -> dict:
    data = None
    headers = {"Authorization": f"Bearer {api_key}"}
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
        headers["X-DashScope-Async"] = "enable"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.load(resp)


def submit_task(api_key: str, audio_url: str, model: str) -> str:
    payload = {
        "model": model,
        "input": {"file_urls": [audio_url]},
        "parameters": {
            "channel_id": [0],
            "language_hints": ["zh", "en"],
        },
    }
    resp = api_request("POST", SUBMIT_URL, api_key, payload)
    task_id = (resp.get("output") or {}).get("task_id")
    if not task_id:
        raise RuntimeError(f"submit failed: {json.dumps(resp, ensure_ascii=False)}")
    return task_id


def wait_task(api_key: str, task_id: str, poll_sec: float = 3.0, max_wait: int = 3600) -> dict:
    deadline = time.time() + max_wait
    while time.time() < deadline:
        resp = api_request("GET", TASK_URL.format(task_id=task_id), api_key)
        status = (resp.get("output") or {}).get("task_status") or resp.get("task_status")
        if status in ("SUCCEEDED", "FAILED", "CANCELED"):
            return resp
        time.sleep(poll_sec)
    raise TimeoutError(f"task {task_id} not finished within {max_wait}s")


def fetch_transcription_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=120) as resp:
        return json.load(resp)


def extract_text(data: dict) -> str:
    # fun-asr / paraformer file result shapes
    if isinstance(data.get("transcripts"), list) and data["transcripts"]:
        t0 = data["transcripts"][0]
        if isinstance(t0, dict) and t0.get("text"):
            return str(t0["text"]).strip()

    if data.get("text"):
        return str(data["text"]).strip()

    sentences = data.get("sentences")
    if isinstance(sentences, list) and sentences:
        parts = []
        for s in sentences:
            if isinstance(s, dict) and s.get("text"):
                parts.append(str(s["text"]))
        if parts:
            return "".join(parts).strip()

    # nested: results -> transcription
    for key in ("results", "transcription", "output"):
        val = data.get(key)
        if isinstance(val, dict):
            try:
                return extract_text(val)
            except ValueError:
                pass
        if isinstance(val, list) and val:
            item = val[0]
            if isinstance(item, dict):
                if item.get("transcription_url"):
                    return extract_text(fetch_transcription_json(item["transcription_url"]))
                try:
                    return extract_text(item)
                except ValueError:
                    pass

    raise ValueError(f"cannot parse transcription JSON: {json.dumps(data, ensure_ascii=False)[:500]}")


def get_transcription_url(task_resp: dict) -> str:
    output = task_resp.get("output") or {}
    results = output.get("results") or []
    if not results:
        raise RuntimeError(f"no results in task response: {json.dumps(task_resp, ensure_ascii=False)}")
    r0 = results[0]
    status = r0.get("subtask_status") or output.get("task_status")
    if status == "FAILED":
        code = r0.get("code", "")
        msg = r0.get("message", "")
        raise RuntimeError(f"subtask failed: {code} {msg}")
    url = r0.get("transcription_url")
    if not url:
        raise RuntimeError(f"missing transcription_url: {json.dumps(r0, ensure_ascii=False)}")
    return url


def main() -> int:
    parser = argparse.ArgumentParser(description="Aliyun DashScope file transcription")
    parser.add_argument("--api-key", required=True)
    parser.add_argument("--audio-url", required=True)
    parser.add_argument("--model", default="fun-asr")
    parser.add_argument("--output", required=True)
    parser.add_argument("--poll-sec", type=float, default=3.0)
    parser.add_argument("--max-wait", type=int, default=3600)
    args = parser.parse_args()

    print(f"==> DashScope submit model={args.model}", file=sys.stderr)
    task_id = submit_task(args.api_key, args.audio_url, args.model)
    print(f"    task_id={task_id}", file=sys.stderr)

    print("==> polling task...", file=sys.stderr)
    task_resp = wait_task(args.api_key, task_id, args.poll_sec, args.max_wait)
    status = (task_resp.get("output") or {}).get("task_status")
    if status != "SUCCEEDED":
        raise RuntimeError(f"task status {status}: {json.dumps(task_resp, ensure_ascii=False)}")

    t_url = get_transcription_url(task_resp)
    print("==> downloading transcription", file=sys.stderr)
    t_json = fetch_transcription_json(t_url)
    text = extract_text(t_json)

    with open(args.output, "w", encoding="utf-8") as f:
        f.write(text + "\n")

    print(f"    chars={len(text)}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (urllib.error.HTTPError, urllib.error.URLError, RuntimeError, TimeoutError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        raise SystemExit(1)
