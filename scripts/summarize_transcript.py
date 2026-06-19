#!/usr/bin/env python3
"""Summarize a podcast transcript via DashScope chat API (map-reduce for long text)."""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.request

CHAT_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
CHUNK_CHARS = 22000
MAX_CHUNKS = 10

SYSTEM = "你是资深播客内容编辑，擅长从逐字稿提炼结构化中文总结，忠实于原文，不编造。"

FINAL_PROMPT = """请根据以下播客《{title}》的逐字稿内容（或分段摘要），写一份中文总结。

必须包含以下三个二级标题（Markdown）：
## 核心内容
（分点概括主要议题与论点，5-10 条）

## 建议
（可落地的个人建议或行动启发，3-6 条）

## 金句
（原文精彩表述，用引用块 > 列出，3-8 条）

要求：简洁、有信息量，不要复述 Show Notes，不要写「以上是总结」之类废话。

---
{body}
"""

CHUNK_PROMPT = """以下是播客《{title}》逐字稿的第 {idx}/{total} 段，请提炼要点（每条一行，中文）：

---
{chunk}
"""


def extract_body(path: str) -> str:
    text = open(path, encoding="utf-8").read()
    # skip YAML frontmatter
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            text = text[end + 4 :]
    # skip metadata block until --- after title
    parts = text.split("\n---\n", 1)
    if len(parts) == 2 and "来源:" in parts[0]:
        text = parts[1]
    text = re.sub(r"\n{3,}", "\n\n", text.strip())
    return text


def split_chunks(text: str) -> list[str]:
    if len(text) <= CHUNK_CHARS:
        return [text]
    chunks: list[str] = []
    start = 0
    while start < len(text) and len(chunks) < MAX_CHUNKS:
        end = min(start + CHUNK_CHARS, len(text))
        if end < len(text):
            cut = text.rfind("\n", start, end)
            if cut > start + CHUNK_CHARS // 2:
                end = cut
        chunks.append(text[start:end].strip())
        start = end
    if start < len(text) and chunks:
        chunks[-1] = (chunks[-1] + "\n\n" + text[start:]).strip()
    return chunks


def chat(api_key: str, model: str, user: str, max_tokens: int = 4096) -> str:
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": SYSTEM},
            {"role": "user", "content": user},
        ],
        "temperature": 0.3,
        "max_tokens": max_tokens,
    }
    req = urllib.request.Request(
        CHAT_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=300) as resp:
        data = json.load(resp)
    content = (data.get("choices") or [{}])[0].get("message", {}).get("content", "")
    if not content:
        raise ValueError(f"empty LLM response: {data}")
    return content.strip()


def summarize(api_key: str, model: str, title: str, body: str) -> str:
    chunks = split_chunks(body)
    print(f"    transcript_chars={len(body)} chunks={len(chunks)}", file=sys.stderr)
    if len(chunks) == 1:
        return chat(api_key, model, FINAL_PROMPT.format(title=title, body=body), max_tokens=4096)
    partials: list[str] = []
    for i, ch in enumerate(chunks, 1):
        print(f"    summarizing chunk {i}/{len(chunks)}...", file=sys.stderr)
        partials.append(
            chat(
                api_key,
                model,
                CHUNK_PROMPT.format(title=title, idx=i, total=len(chunks), chunk=ch),
                max_tokens=2048,
            )
        )
    merged = "\n\n".join(f"### 第{i}段要点\n{p}" for i, p in enumerate(partials, 1))
    return chat(api_key, model, FINAL_PROMPT.format(title=title, body=merged), max_tokens=4096)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--api-key", required=True)
    p.add_argument("--model", default="qwen-plus")
    p.add_argument("--transcript", required=True)
    p.add_argument("--title", default="")
    p.add_argument("--output", required=True)
    args = p.parse_args()

    body = extract_body(args.transcript)
    title = args.title or "播客"
    if not body:
        raise ValueError("empty transcript body")

    print(f"==> Summarize model={args.model}", file=sys.stderr)
    summary = summarize(args.api_key, args.model, title, body)
    with open(args.output, "w", encoding="utf-8") as f:
        f.write(summary + "\n")
    print(f"    summary_chars={len(summary)}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        raise SystemExit(1)
