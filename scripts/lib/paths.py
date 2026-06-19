#!/usr/bin/env python3
"""Episode title → safe local filenames (keep Chinese, no pinyin slug)."""

from __future__ import annotations

import os
import re
import sys

_INVALID = re.compile(r'[<>:"/\\|?*\x00-\x1f]')


def sanitize_title(title: str, max_len: int = 120) -> str:
    s = (title or "").strip()
    s = _INVALID.sub("", s)
    s = re.sub(r"\s+", " ", s)
    s = s.strip(" .")
    if len(s) > max_len:
        s = s[:max_len].rstrip(" .")
    return s or "未命名播客"


def transcript_filename(title: str) -> str:
    return f"{sanitize_title(title)}.md"


def summary_filename(title: str) -> str:
    return f"{sanitize_title(title)} - 总结.md"


def transcript_path(output_dir: str, title: str) -> str:
    return os.path.join(output_dir, transcript_filename(title))


def summary_path(output_dir: str, title: str) -> str:
    return os.path.join(output_dir, summary_filename(title))


def summary_path_for_transcript(transcript_path: str) -> str:
    base = os.path.basename(transcript_path)
    if base.endswith(".md"):
        base = base[:-3]
    if base.endswith(" - 总结"):
        base = base[: -len(" - 总结")]
    return os.path.join(os.path.dirname(transcript_path), f"{base} - 总结.md")


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: paths.py sanitize|transcript-path|summary-path|summary-for-transcript ...", file=sys.stderr)
        return 1
    cmd = sys.argv[1]
    if cmd == "sanitize":
        print(sanitize_title(sys.argv[2]))
    elif cmd == "transcript-path":
        print(transcript_path(sys.argv[2], sys.argv[3]))
    elif cmd == "summary-path":
        print(summary_path(sys.argv[2], sys.argv[3]))
    elif cmd == "summary-for-transcript":
        print(summary_path_for_transcript(sys.argv[2]))
    else:
        print(f"unknown command: {cmd}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
