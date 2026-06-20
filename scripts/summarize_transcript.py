#!/usr/bin/env python3
"""Deep-extract podcast insights from transcript via DashScope chat API (map-reduce for long text)."""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.request

CHAT_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
CHUNK_CHARS = 22000
MAX_CHUNKS = 12

SYSTEM = """你是一个专业的播客深度提炼助手。
你擅长从完整逐字稿中提炼结构化深度总结，忠实于原文，引用准确，不编造嘉宾未说过的话。"""

FINAL_PROMPT = """请对以下播客《{title}》的全量逐字稿（或各段深度提炼素材）进行深度提炼。
输出结构如下（全部章节都要有内容，不能跳过；若某节确实无素材则删除该节，但须尽力从全文中挖掘）：

已知元数据（填入「一、本期基本信息」，能从文稿识别的嘉宾等信息请补充）：
- 节目标题：{title}
- 时长：{duration}
- 创建日期：{created_at}
- 来源 url：{url}

## 一、本期基本信息
- 嘉宾：
- 核心主题：
- 时长：{duration}
- 一句话概述：
- 创建日期：{created_at}
- 标签：（总结提炼内容标签）
- 来源 url：{url}

## 二、核心观点提炼
按话题分章节展示，每个观点须附原文原话。

每节要求：
- 提炼出 2-4 个独立观点
- 每个观点格式：【观点一句话概括】+ 原文原话（引号包裹）+ 为什么重要（1-2句）
- 不要总结，要直接引用嘉宾真实表述

## 三、时间线高光时刻
按时间顺序（时间戳精确到分钟），每 5-10 分钟摘录一个最精彩或信息密度最高的时刻，格式：
| 时间 | 话题 | 核心内容 | 精彩程度 |

说明：若逐字稿无真实时间戳，请根据全文位置与总时长 {duration} 按比例估算时间点（精确到分钟）。

## 四、金句摘录（10-15句）
从全文中摘录最有冲击力、最能代表嘉宾思想的原话，每条加序号，附这句话在文稿中出现的大致位置（开头/中间/结尾/后期）。

## 五、可行动启发清单（10-15条）
每条格式：【启发名称】+ 适用场景 + 具体可操作的行动步骤
分为三个维度：
- 适合管理者/职场人
- 适合普通职场人
- 适合企业 AI 落地团队负责人

## 六、批判性思考
- 本期内容中有哪些观点嘉宾可能有所保留或没有展开？
- 有哪些地方存在逻辑跳跃或论证不足？
- 有哪些观点放在中国环境下需要调整才能落地？

要求：
1. 必须读取并提炼全量逐字稿素材，不能只读开头
2. 中文输出
3. 原文引用必须准确，不能改变原意
4. 每个章节都要有实质性内容，空章节直接删除该节
5. 行动启发要具体、可执行，不能是空话套话

---
{body}
"""

CHUNK_PROMPT = """以下是播客《{title}》逐字稿的第 {idx}/{total} 段（全文共 {total} 段，本段约占全文的 1/{total}）。
请做**深度分段提炼**（供后续合并成全篇总结），输出：

1. **本段话题**（1-3 个）
2. **嘉宾/主持人关键原话**（逐条用引号包裹，尽量 verbatim，至少 5 条）
3. **金句候选**（2-5 条，带引号）
4. **信息密度最高的时刻**（描述本段最精彩的 1-2 个讨论点）
5. **可行动启发候选**（2-4 条，尽量具体）
6. **批判性思考线索**（本段中论证薄弱、未展开或需本土化调整的点，如有）

---
{chunk}
"""


def extract_metadata(path: str) -> dict[str, str]:
    text = open(path, encoding="utf-8").read()
    meta = {"title": "", "url": "", "duration": "未知", "created_at": "未知"}

    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            for line in text[3:end].splitlines():
                if ":" not in line:
                    continue
                key, _, val = line.partition(":")
                val = val.strip().strip('"')
                if key == "title":
                    meta["title"] = val
                elif key == "source_url":
                    meta["url"] = val
                elif key == "duration":
                    meta["duration"] = val
                elif key == "transcribed_at":
                    meta["created_at"] = val

    if not meta["title"]:
        m = re.search(r"^#\s+(.+)$", text, re.M)
        if m:
            meta["title"] = m.group(1).strip()
    if not meta["url"]:
        m = re.search(r"^来源:\s*(.+)$", text, re.M)
        if m:
            meta["url"] = m.group(1).strip()
    if meta["duration"] == "未知":
        m = re.search(r"^时长:\s*(.+)$", text, re.M)
        if m:
            meta["duration"] = m.group(1).strip()
    if meta["created_at"] == "未知":
        m = re.search(r"^转录时间:\s*(.+)$", text, re.M)
        if m:
            meta["created_at"] = m.group(1).strip()

    return meta


def extract_body(path: str) -> str:
    text = open(path, encoding="utf-8").read()
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            text = text[end + 4 :]
    parts = text.split("\n---\n", 1)
    if len(parts) == 2 and "来源:" in parts[0]:
        text = parts[1]
    return re.sub(r"\n{3,}", "\n\n", text.strip())


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


def chat(api_key: str, model: str, user: str, max_tokens: int = 8192) -> str:
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
    with urllib.request.urlopen(req, timeout=600) as resp:
        data = json.load(resp)
    content = (data.get("choices") or [{}])[0].get("message", {}).get("content", "")
    if not content:
        raise ValueError(f"empty LLM response: {data}")
    return content.strip()


def build_final_prompt(title: str, meta: dict[str, str], body: str) -> str:
    return FINAL_PROMPT.format(
        title=title,
        duration=meta.get("duration") or "未知",
        created_at=meta.get("created_at") or "未知",
        url=meta.get("url") or "未知",
        body=body,
    )


def summarize(
    api_key: str,
    model: str,
    title: str,
    meta: dict[str, str],
    body: str,
) -> str:
    chunks = split_chunks(body)
    print(f"    transcript_chars={len(body)} chunks={len(chunks)}", file=sys.stderr)
    if len(chunks) == 1:
        return chat(api_key, model, build_final_prompt(title, meta, body), max_tokens=8192)

    partials: list[str] = []
    for i, ch in enumerate(chunks, 1):
        print(f"    deep-extract chunk {i}/{len(chunks)}...", file=sys.stderr)
        partials.append(
            chat(
                api_key,
                model,
                CHUNK_PROMPT.format(title=title, idx=i, total=len(chunks), chunk=ch),
                max_tokens=4096,
            )
        )
    merged = "\n\n".join(f"### 第{i}段深度提炼\n{p}" for i, p in enumerate(partials, 1))
    return chat(api_key, model, build_final_prompt(title, meta, merged), max_tokens=8192)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--api-key", required=True)
    p.add_argument("--model", default="qwen-long")
    p.add_argument("--transcript", required=True)
    p.add_argument("--title", default="")
    p.add_argument("--output", required=True)
    args = p.parse_args()

    meta = extract_metadata(args.transcript)
    body = extract_body(args.transcript)
    title = args.title or meta.get("title") or "播客"
    if not body:
        raise ValueError("empty transcript body")

    print(f"==> Deep extract model={args.model}", file=sys.stderr)
    summary = summarize(args.api_key, args.model, title, meta, body)
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
