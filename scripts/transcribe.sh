#!/usr/bin/env bash
# Transcribe a Xiaoyuzhou podcast episode to Markdown.
#
# Usage:
#   transcribe.sh [--provider aliyun|doubao|siliconflow] [--model MODEL] <url> [out.md]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

PROVIDER=""
MODEL_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) PROVIDER="${2:?}"; shift 2 ;;
    --model) MODEL_OVERRIDE="${2:?}"; shift 2 ;;
    -h|--help)
      echo "Usage: transcribe.sh [--provider aliyun|doubao|siliconflow] [--model MODEL] <episode_url> [output.md]"
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
AUDIO_BITRATE="64k"

PROVIDER="${PROVIDER:-$(xy_get_provider)}"

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

for cmd in ffmpeg ffprobe curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: $cmd required" >&2; exit 1; }
done
mkdir -p "$TMPDIR"

NUM_CHUNKS=1
ENGINE_NAME=""
DURATION_MIN=0
DURATION_SEC=0
TITLE=""
AUDIO_URL=""
DURATION=""

fetch_episode_meta() {
  echo "==> Fetching episode page"
  PAGE=$(curl -sL "$URL" -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)")
  AUDIO_URL=$(echo "$PAGE" | grep -oE 'https://media\.xyzcdn\.net/[^"[:space:]]+\.(m4a|mp3|mp4a)' | head -1 || true)

  if [[ -z "$AUDIO_URL" ]]; then
    python3 - "$PAGE" > "$TMPDIR/meta.env" <<'PY'
import re, json, sys
html = sys.stdin.read()
m = re.search(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', html, re.S)
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
  [[ -n "$AUDIO_URL" ]] || { echo "Error: cannot extract audio URL" >&2; exit 1; }
  echo "    Title: $TITLE"
  echo "    Audio: $AUDIO_URL"
}

set_duration_vars() {
  if [[ -z "${DURATION:-}" || "$DURATION" == "0" ]]; then
    DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$AUDIO_URL" 2>/dev/null | cut -d. -f1 || echo 0)
  fi
  [[ -n "$DURATION" && "$DURATION" != "0" ]] || DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$TMPDIR/mono.mp3" 2>/dev/null | cut -d. -f1 || echo 0)
  DURATION_MIN=$((DURATION / 60))
  DURATION_SEC=$((DURATION % 60))
}

download_mono_mp3() {
  echo "==> Downloading audio"
  EXT="${AUDIO_URL##*.}"
  curl -sL -o "$TMPDIR/original.$EXT" "$AUDIO_URL"
  DURATION=${DURATION:-$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$TMPDIR/original.$EXT" 2>/dev/null | cut -d. -f1)}
  echo "==> Transcoding to mono mp3"
  ffmpeg -y -i "$TMPDIR/original.$EXT" -b:a "$AUDIO_BITRATE" -ac 1 "$TMPDIR/mono.mp3" 2>/dev/null
  set_duration_vars
}

transcribe_aliyun() {
  local key model
  key="$(xy_get_dashscope_key)"
  model="${MODEL_OVERRIDE:-$(xy_get_dashscope_model)}"
  [[ -n "$key" ]] || { echo "Error: configure.sh aliyun sk-..." >&2; exit 1; }
  python3 "$SCRIPT_DIR/aliyun_transcribe.py" \
    --api-key "$key" --audio-url "$AUDIO_URL" --model "$model" \
    --output "$TMPDIR/transcript_0.txt"
  ENGINE_NAME="Aliyun DashScope $model"
  set_duration_vars
}

transcribe_doubao() {
  local api app acc args=()
  api="$(xy_get_volc_api_key)"
  app="$(xy_get_volc_app_key)"
  acc="$(xy_get_volc_access_key)"
  if [[ -z "$api" ]] && { [[ -z "$app" ]] || [[ -z "$acc" ]]; }; then
    echo "Error: configure.sh doubao ..." >&2; exit 1
  fi

  args=(--output "$TMPDIR/transcript_0.txt")
  if [[ -n "$api" ]]; then args+=(--api-key "$api"); else args+=(--app-key "$app" --access-key "$acc"); fi

  echo "==> Transcribing (Doubao flash, try URL)"
  if python3 "$SCRIPT_DIR/doubao_transcribe.py" "${args[@]}" --audio-url "$AUDIO_URL" 2>/dev/null; then
    ENGINE_NAME="Doubao 大模型录音文件极速版"
    set_duration_vars
    return
  fi

  echo "    URL failed (format?), uploading mp3 via base64..."
  download_mono_mp3
  python3 "$SCRIPT_DIR/doubao_transcribe.py" "${args[@]}" --audio-file "$TMPDIR/mono.mp3"
  ENGINE_NAME="Doubao 大模型录音文件极速版"
}

transcribe_siliconflow() {
  local key model
  key="$(xy_get_siliconflow_key)"
  model="${MODEL_OVERRIDE:-$(xy_get_siliconflow_model)}"
  [[ -n "$key" ]] || { echo "Error: configure.sh siliconflow sk-..." >&2; exit 1; }
  download_mono_mp3
  python3 "$SCRIPT_DIR/siliconflow_transcribe.py" \
    --api-key "$key" --model "$model" \
    --audio-file "$TMPDIR/mono.mp3" --output "$TMPDIR/transcript_0.txt"
  ENGINE_NAME="SiliconFlow $model"
}

merge_output() {
  echo "==> Merging and cleaning"
  python3 - "$TMPDIR" "$OUTPUT" "$URL" "$TITLE" "$DURATION_MIN" "$DURATION_SEC" "$ENGINE_NAME" <<'PY'
import re, sys
from datetime import datetime

tmpdir, out, url, title, dm, ds, engine = sys.argv[1:8]
text = open(f"{tmpdir}/transcript_0.txt", encoding="utf-8").read()
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
引擎: {engine}

---

{text.strip()}
"""
open(out, "w", encoding="utf-8").write(header)
print(f"    Output: {out}")
print(f"    Chars: {len(text)}")
PY
}

fetch_episode_meta
case "$PROVIDER" in
  aliyun) transcribe_aliyun ;;
  doubao) transcribe_doubao ;;
  siliconflow) transcribe_siliconflow ;;
  minimax)
    echo "Error: MiniMax 录音转写 ASR 尚未在官方开放平台开放，请改用:" >&2
    echo "  bash $SCRIPT_DIR/transcribe.sh --provider aliyun|doubao|siliconflow <url>" >&2
    echo "可先 bash $SCRIPT_DIR/configure.sh minimax sk-... 保存 Key 备用。" >&2
    exit 1
    ;;
  *) echo "Error: unknown provider '$PROVIDER'" >&2; exit 1 ;;
esac
merge_output
echo "==> Done"
