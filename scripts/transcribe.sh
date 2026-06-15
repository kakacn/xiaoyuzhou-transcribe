#!/usr/bin/env bash
# Transcribe a Xiaoyuzhou podcast episode to Markdown.
#
# Usage:
#   transcribe.sh [--provider aliyun|groq] [--polish] [--model fun-asr] <episode_url> [output.md]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

POLISH=0
PROVIDER=""
MODEL_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --polish) POLISH=1; shift ;;
    --provider) PROVIDER="${2:?}"; shift 2 ;;
    --model) MODEL_OVERRIDE="${2:?}"; shift 2 ;;
    -h|--help)
      echo "Usage: transcribe.sh [--provider aliyun|groq] [--polish] [--model MODEL] <episode_url> [output.md]"
      exit 0
      ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) break ;;
  esac
done

URL="${1:?Usage: transcribe.sh <episode_url> [output.md]}"
EPISODE_ID=$(echo "$URL" | grep -oE '[a-f0-9]{24}' | tail -1)
OUTPUT="${2:-/tmp/xiaoyuzhou_${EPISODE_ID:-out}.md}"
TMPDIR="/tmp/xiaoyuzhou_$$"
MAX_CHUNK_MB=20
AUDIO_BITRATE="64k"
WHISPER_MODEL="whisper-large-v3"

PROVIDER="${PROVIDER:-$(xy_get_provider)}"

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

for cmd in ffmpeg ffprobe curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: $cmd required" >&2; exit 1; }
done

mkdir -p "$TMPDIR"

fetch_episode_meta() {
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
print(f'AUDIO_URL={url!r}')
print(f'TITLE={ep.get("title", "")!r}')
print(f'DURATION={ep.get("duration", "")!r}')
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
}

download_and_probe() {
  echo "==> Downloading audio"
  EXT="${AUDIO_URL##*.}"
  curl -sL -o "$TMPDIR/original.$EXT" "$AUDIO_URL"
  DURATION=${DURATION:-$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$TMPDIR/original.$EXT" 2>/dev/null | cut -d. -f1)}
  DURATION_MIN=$((DURATION / 60))
  DURATION_SEC=$((DURATION % 60))
  echo "    Duration: ${DURATION_MIN}m ${DURATION_SEC}s"
  echo "==> Transcoding to mono mp3"
  ffmpeg -y -i "$TMPDIR/original.$EXT" -b:a "$AUDIO_BITRATE" -ac 1 "$TMPDIR/mono.mp3" 2>/dev/null
}

transcribe_groq_chunks() {
  local key mono_size max_bytes num_chunks
  key="$(xy_get_groq_key)"
  [[ -n "$key" ]] || { echo "Error: Groq key missing" >&2; exit 1; }

  mono_size=$(stat -f%z "$TMPDIR/mono.mp3" 2>/dev/null || stat -c%s "$TMPDIR/mono.mp3")
  max_bytes=$((MAX_CHUNK_MB * 1024 * 1024))

  if [[ "$mono_size" -le "$max_bytes" ]]; then
    cp "$TMPDIR/mono.mp3" "$TMPDIR/chunk_0.mp3"
    NUM_CHUNKS=1
  else
    NUM_CHUNKS=$(( (mono_size / max_bytes) + 1 ))
    local chunk_duration=$(( DURATION / NUM_CHUNKS + 10 ))
    echo "==> Splitting into $NUM_CHUNKS chunks (Groq)"
    for i in $(seq 0 $((NUM_CHUNKS - 1))); do
      local start=$((i * chunk_duration))
      ffmpeg -y -i "$TMPDIR/mono.mp3" -ss "$start" -t "$chunk_duration" -c copy "$TMPDIR/chunk_${i}.mp3" 2>/dev/null
    done
  fi

  echo "==> Transcribing (Groq $WHISPER_MODEL)"
  for i in $(seq 0 $((NUM_CHUNKS - 1))); do
    echo -n "    chunk $((i+1))/$NUM_CHUNKS ... "
    local resp http body
    resp=$(curl -s -w "\n%{http_code}" \
      https://api.groq.com/openai/v1/audio/transcriptions \
      -H "Authorization: Bearer $key" \
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
        -H "Authorization: Bearer $key" \
        -F file="@$TMPDIR/chunk_${i}.mp3" \
        -F model="$WHISPER_MODEL" \
        -F language="zh" \
        -F prompt="以下是一段中文普通话播客录音，请输出包含完整中文标点（，。？！：；）的转写文本。" \
        -F response_format="text")
      http=$(echo "$resp" | tail -1)
      body=$(echo "$resp" | sed '$d')
    fi
    [[ "$http" == "200" ]] || { echo "HTTP $http: $body" >&2; exit 1; }
    echo "$body" > "$TMPDIR/transcript_${i}.txt"
    echo "done ($(wc -m < "$TMPDIR/transcript_${i}.txt" | tr -d ' ') chars)"
  done
  GROQ_ENGINE="Groq Whisper large-v3"
}

transcribe_aliyun() {
  local key model
  key="$(xy_get_dashscope_key)"
  [[ -n "$key" ]] || { echo "Error: DashScope key missing. Run: configure.sh aliyun sk-..." >&2; exit 1; }
  model="${MODEL_OVERRIDE:-$(xy_get_dashscope_model)}"

  echo "==> Transcribing (Aliyun DashScope $model)"
  if python3 "$SCRIPT_DIR/aliyun_transcribe.py" \
      --api-key "$key" \
      --audio-url "$AUDIO_URL" \
      --model "$model" \
      --output "$TMPDIR/transcript_0.txt"; then
    NUM_CHUNKS=1
    GROQ_ENGINE="Aliyun DashScope $model"
    if [[ -z "${DURATION:-}" || "$DURATION" == "0" ]]; then
      DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$AUDIO_URL" 2>/dev/null | cut -d. -f1 || echo 0)
    fi
    DURATION_MIN=$((DURATION / 60))
    DURATION_SEC=$((DURATION % 60))
    return 0
  fi

  echo "    Aliyun URL transcription failed, trying Groq fallback..." >&2
  if [[ -n "$(xy_get_groq_key)" ]]; then
    download_and_probe
    transcribe_groq_chunks
    GROQ_ENGINE="Groq Whisper large-v3 (fallback)"
    return 0
  fi
  echo "Error: Aliyun failed and no Groq fallback key configured" >&2
  exit 1
}

polish_groq() {
  local key
  key="$(xy_get_groq_key)"
  [[ -n "$key" ]] || { echo "Warning: --polish needs Groq key, skipping" >&2; return; }
  echo "==> Polishing punctuation (Groq Llama 3.3 70B)"
  for i in $(seq 0 $((NUM_CHUNKS - 1))); do
    IN_FILE="$TMPDIR/transcript_${i}.txt" OUT_FILE="$TMPDIR/polished_${i}.txt" \
    GROQ_API_KEY="$key" python3 <<'PY'
import json, os, urllib.request
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
}

merge_output() {
  echo "==> Merging and cleaning"
  python3 - "$TMPDIR" "$OUTPUT" "$URL" "$TITLE" "$DURATION_MIN" "$DURATION_SEC" "$POLISH" "$NUM_CHUNKS" "$GROQ_ENGINE" <<'PY'
import re, sys
from datetime import datetime

tmpdir, out, url, title, dm, ds, polish, n, engine = sys.argv[1:10]
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
polish_note = " + Llama polish" if polish else ""
header = f"""# {title}

来源: {url}
时长: {dm}分{ds}秒
转录时间: {datetime.now().strftime('%Y-%m-%d %H:%M')}
引擎: {engine}{polish_note}

---

{text.strip()}
"""
open(out, "w", encoding="utf-8").write(header)
print(f"    Output: {out}")
print(f"    Chars: {len(text)}")
PY
}

# --- main ---
fetch_episode_meta
NUM_CHUNKS=1
GROQ_ENGINE=""
DURATION_MIN=0
DURATION_SEC=0

case "$PROVIDER" in
  aliyun)
    transcribe_aliyun
  ;;
  groq)
    download_and_probe
    transcribe_groq_chunks
  ;;
  *)
    echo "Error: unknown provider '$PROVIDER'" >&2
    exit 1
  ;;
esac

[[ "$POLISH" -eq 1 ]] && polish_groq
merge_output
echo "==> Done"
