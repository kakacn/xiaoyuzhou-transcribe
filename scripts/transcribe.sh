#!/usr/bin/env bash
# Transcribe a Xiaoyuzhou podcast episode to Markdown.
# Usage: transcribe.sh [--polish] <episode_url> [output.md]

set -euo pipefail

POLISH=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --polish) POLISH=1; shift ;;
    -h|--help)
      echo "Usage: transcribe.sh [--polish] <xiaoyuzhou_episode_url> [output.md]"
      exit 0
      ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) break ;;
  esac
done

URL="${1:?Usage: transcribe.sh [--polish] <episode_url> [output.md]}"
EPISODE_ID=$(echo "$URL" | grep -oE '[a-f0-9]{24}' | tail -1)
OUTPUT="${2:-/tmp/xiaoyuzhou_${EPISODE_ID:-out}.md}"
TMPDIR="/tmp/xiaoyuzhou_$$"
MAX_CHUNK_MB=20
AUDIO_BITRATE="64k"
WHISPER_MODEL="whisper-large-v3"

load_groq_key() {
  if [[ -n "${GROQ_API_KEY:-}" ]]; then return; fi
  local keyfile="$HOME/.xiaoyuzhou-transcribe/groq_api_key"
  [[ -f "$keyfile" ]] || {
    echo "Error: Groq key missing." >&2
    echo "  1. Open https://console.groq.com/keys and create an API key" >&2
    echo "  2. Run: bash scripts/configure.sh gsk_..." >&2
    exit 1
  }
  GROQ_API_KEY=$(tr -d '[:space:]' < "$keyfile")
  export GROQ_API_KEY
}

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

for cmd in ffmpeg ffprobe curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: $cmd required" >&2; exit 1; }
done
load_groq_key

mkdir -p "$TMPDIR"

echo "==> Fetching episode page"
PAGE=$(curl -sL "$URL" -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)")

AUDIO_URL=$(echo "$PAGE" | grep -oE 'https://media\.xyzcdn\.net/[^"[:space:]]+\.(m4a|mp3|mp4a)' | head -1 || true)
TITLE=""
DURATION=""

if [[ -z "$AUDIO_URL" ]]; then
  python3 - "$PAGE" > "$TMPDIR/meta.env" <<'PY'
import re, json, sys
html = sys.stdin.read()
m = re.search(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', html, re.S)
if not m:
    sys.exit(1)
ep = json.loads(m.group(1))["props"]["pageProps"]["episode"]
media = ep.get("media", {})
url = (media.get("backupSource") or {}).get("url") or (ep.get("enclosure") or {}).get("url") or ""
title = ep.get("title", "")
duration = ep.get("duration", "")
print(f'AUDIO_URL={url!r}')
print(f'TITLE={title!r}')
print(f'DURATION={duration!r}')
PY
  # shellcheck disable=SC1090
  source "$TMPDIR/meta.env"
  AUDIO_URL="${AUDIO_URL//\'/}"
  TITLE="${TITLE//\'/}"
  DURATION="${DURATION//\'/}"
else
  TITLE=$(echo "$PAGE" | grep -o '"title":"[^"]*"' | head -1 | sed 's/"title":"//;s/"$//')
fi

[[ -n "$AUDIO_URL" ]] || { echo "Error: cannot extract audio URL from page" >&2; exit 1; }

echo "    Title: $TITLE"
echo "    Audio: $AUDIO_URL"

echo "==> Downloading audio"
EXT="${AUDIO_URL##*.}"
curl -sL -o "$TMPDIR/original.$EXT" "$AUDIO_URL"

DURATION=${DURATION:-$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$TMPDIR/original.$EXT" 2>/dev/null | cut -d. -f1)}
DURATION_MIN=$((DURATION / 60))
DURATION_SEC=$((DURATION % 60))
echo "    Duration: ${DURATION_MIN}m ${DURATION_SEC}s"

echo "==> Transcoding to mono mp3"
ffmpeg -y -i "$TMPDIR/original.$EXT" -b:a "$AUDIO_BITRATE" -ac 1 "$TMPDIR/mono.mp3" 2>/dev/null
MONO_SIZE=$(stat -f%z "$TMPDIR/mono.mp3" 2>/dev/null || stat -c%s "$TMPDIR/mono.mp3")
MAX_BYTES=$((MAX_CHUNK_MB * 1024 * 1024))

if [[ "$MONO_SIZE" -le "$MAX_BYTES" ]]; then
  cp "$TMPDIR/mono.mp3" "$TMPDIR/chunk_0.mp3"
  NUM_CHUNKS=1
else
  NUM_CHUNKS=$(( (MONO_SIZE / MAX_BYTES) + 1 ))
  CHUNK_DURATION=$(( DURATION / NUM_CHUNKS + 10 ))
  echo "==> Splitting into $NUM_CHUNKS chunks"
  for i in $(seq 0 $((NUM_CHUNKS - 1))); do
    START=$((i * CHUNK_DURATION))
    ffmpeg -y -i "$TMPDIR/mono.mp3" -ss "$START" -t "$CHUNK_DURATION" -c copy "$TMPDIR/chunk_${i}.mp3" 2>/dev/null
  done
fi

transcribe_chunk() {
  local i="$1"
  local out="$TMPDIR/transcript_${i}.txt"
  echo -n "    chunk $((i+1))/$NUM_CHUNKS ... "
  local resp http body
  resp=$(curl -s -w "\n%{http_code}" \
    https://api.groq.com/openai/v1/audio/transcriptions \
    -H "Authorization: Bearer $GROQ_API_KEY" \
    -F file="@$TMPDIR/chunk_${i}.mp3" \
    -F model="$WHISPER_MODEL" \
    -F language="zh" \
    -F prompt="以下是一段中文普通话播客录音，请输出包含完整中文标点（，。？！：；）的转写文本。" \
    -F response_format="text")
  http=$(echo "$resp" | tail -1)
  body=$(echo "$resp" | sed '$d')
  if [[ "$http" == "429" ]]; then
    echo "rate limited, waiting 90s"
    sleep 90
    resp=$(curl -s -w "\n%{http_code}" \
      https://api.groq.com/openai/v1/audio/transcriptions \
      -H "Authorization: Bearer $GROQ_API_KEY" \
      -F file="@$TMPDIR/chunk_${i}.mp3" \
      -F model="$WHISPER_MODEL" \
      -F language="zh" \
      -F prompt="以下是一段中文普通话播客录音，请输出包含完整中文标点（，。？！：；）的转写文本。" \
      -F response_format="text")
    http=$(echo "$resp" | tail -1)
    body=$(echo "$resp" | sed '$d')
  fi
  [[ "$http" == "200" ]] || { echo "HTTP $http: $body" >&2; exit 1; }
  echo "$body" > "$out"
  echo "done ($(wc -m < "$out" | tr -d ' ') chars)"
}

echo "==> Transcribing (Groq $WHISPER_MODEL)"
for i in $(seq 0 $((NUM_CHUNKS - 1))); do
  transcribe_chunk "$i"
done

if [[ "$POLISH" -eq 1 ]]; then
  echo "==> Polishing punctuation (Llama 3.3 70B)"
  for i in $(seq 0 $((NUM_CHUNKS - 1))); do
    IN_FILE="$TMPDIR/transcript_${i}.txt" OUT_FILE="$TMPDIR/polished_${i}.txt" \
    GROQ_API_KEY="$GROQ_API_KEY" python3 <<'PY'
import json, os, sys, urllib.request

key = os.environ["GROQ_API_KEY"]
inp = os.environ["IN_FILE"]
outp = os.environ["OUT_FILE"]
text = open(inp, encoding="utf-8").read().strip()
prompt = (
    "以下是一段中文播客转写，请只在合适位置补充中文标点并适度分段。"
    "不得增删改任何汉字，不得总结。直接输出全文：\n\n" + text
)
body = json.dumps({
    "model": "llama-3.3-70b-versatile",
    "temperature": 0.2,
    "max_completion_tokens": 8192,
    "messages": [{"role": "user", "content": prompt}],
}).encode()
req = urllib.request.Request(
    "https://api.groq.com/openai/v1/chat/completions",
    data=body,
    headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
)
with urllib.request.urlopen(req, timeout=180) as r:
    result = json.load(r)["choices"][0]["message"]["content"].strip()
open(outp, "w", encoding="utf-8").write(result + "\n")
PY
  done
fi

echo "==> Merging and cleaning"
python3 - "$TMPDIR" "$OUTPUT" "$URL" "$TITLE" "$DURATION_MIN" "$DURATION_SEC" "$POLISH" "$NUM_CHUNKS" <<'PY'
import re, sys
from datetime import datetime

tmpdir, out, url, title, dm, ds, polish, n = sys.argv[1:9]
n = int(n)
polish = int(polish)
parts = []
for i in range(n):
    fn = f"{tmpdir}/polished_{i}.txt" if polish else f"{tmpdir}/transcript_{i}.txt"
    if polish and not __import__("os").path.exists(fn):
        fn = f"{tmpdir}/transcript_{i}.txt"
    parts.append(open(fn, encoding="utf-8").read())
text = "\n".join(parts)
noise = [
    r"请不吝点赞\s*订阅\s*转发\s*打赏支持明镜与点点栏目",
    r"请不吝点赞\s*订阅\s*转发\s*打赏支持明镜及点点栏目",
    r"请输出包含完整中文标点[^。]*。",
    r"请输出包含文本。",
    r"感谢观看",
]
for p in noise:
    text = re.sub(p, "", text)
text = re.sub(r"\n{3,}", "\n\n", text)
header = f"""# {title}

来源: {url}
时长: {dm}分{ds}秒
转录时间: {datetime.now().strftime('%Y-%m-%d %H:%M')}
引擎: Groq Whisper large-v3{' + Llama polish' if polish else ''}

---

{text.strip()}
"""
open(out, "w", encoding="utf-8").write(header)
print(f"    Output: {out}")
print(f"    Chars: {len(text)}")
PY

echo "==> Done"
