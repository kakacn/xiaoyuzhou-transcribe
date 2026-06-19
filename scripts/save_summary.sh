#!/usr/bin/env bash
# Save podcast summary Markdown next to the transcript file.
#
# Usage:
#   save_summary.sh --transcript /path/播客标题.md summary.md
#   save_summary.sh --transcript /path/播客标题.md -   # read summary from stdin
#   save_summary.sh summary.md                         # uses last_run.env transcript

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

TRANSCRIPT=""
CONTENT_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --transcript) TRANSCRIPT="${2:?}"; shift 2 ;;
    -h|--help)
      echo "Usage: save_summary.sh [--transcript PATH] [summary.md|-]"
      exit 0
      ;;
    -)
      CONTENT_ARG="-"
      shift
      break
      ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) CONTENT_ARG="$1"; shift; break ;;
  esac
done

if [[ -z "$TRANSCRIPT" && -f "$(xy_config_path last_run.env)" ]]; then
  # shellcheck disable=SC1090
  source "$(xy_config_path last_run.env)"
  TRANSCRIPT="${TRANSCRIPT_PATH:-}"
fi

[[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]] || {
  echo "Error: transcript not found. Run transcribe.sh first or pass --transcript" >&2
  exit 1
}

SUMMARY_PATH=$(python3 "$SCRIPT_DIR/lib/paths.py" summary-for-transcript "$TRANSCRIPT")

TITLE=$(python3 - "$TRANSCRIPT" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"^#\s+(.+)$", text, re.M)
print(m.group(1).strip() if m else "")
PY
)

URL=$(grep -m1 '^来源:' "$TRANSCRIPT" 2>/dev/null | sed 's/^来源:[[:space:]]*//' || true)

if [[ -n "$CONTENT_ARG" ]]; then
  if [[ "$CONTENT_ARG" == "-" ]]; then
    BODY=$(cat)
  else
    [[ -f "$CONTENT_ARG" ]] || { echo "Error: file not found: $CONTENT_ARG" >&2; exit 1; }
    BODY=$(cat "$CONTENT_ARG")
  fi
else
  BODY=$(cat)
fi

[[ -n "${BODY//[[:space:]]/}" ]] || { echo "Error: empty summary content" >&2; exit 1; }

mkdir -p "$(dirname "$SUMMARY_PATH")"

python3 - "$SUMMARY_PATH" "$TITLE" "$URL" "$TRANSCRIPT" "$BODY" <<'PY'
import sys
from datetime import datetime

out, title, url, transcript, body = sys.argv[1:6]
body = body.strip()
if not body.startswith("#"):
    body = f"# {title} — 总结\n\n{body}"
header = f"""---
title: "{title} — 总结"
type: summary
source_transcript: "{transcript}"
source_url: "{url}"
created: {datetime.now().strftime('%Y-%m-%d %H:%M')}
---

"""
open(out, "w", encoding="utf-8").write(header + body + "\n")
print(f"    Summary: {out}")
PY

# Update last_run.env
xy_write_last_run "$TRANSCRIPT" "$SUMMARY_PATH" "$TITLE" "$URL"
echo "==> Summary saved"
