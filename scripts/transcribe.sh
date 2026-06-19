#!/usr/bin/env bash
# Transcribe a Xiaoyuzhou podcast episode to Markdown.
#
# Usage:
#   transcribe.sh [--provider aliyun|doubao|siliconflow] [--model MODEL] <url> [out.md]
#
# Default output: ~/.xiaoyuzhou-transcribe/output/<播客标题>.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

PROVIDER=""
MODEL_OVERRIDE=""
EXPLICIT_OUTPUT=""
SKIP_SUMMARY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) PROVIDER="${2:?}"; shift 2 ;;
    --model) MODEL_OVERRIDE="${2:?}"; shift 2 ;;
    --no-summary) SKIP_SUMMARY=1; shift ;;
    -h|--help)
      echo "Usage: transcribe.sh [--provider aliyun|doubao|siliconflow] [--model MODEL] [--no-summary] <episode_url> [output.md]"
      echo "Default: transcribe + auto summary (DashScope qwen-plus) → output/<播客标题>.md and <播客标题> - 总结.md"
      exit 0
      ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) break ;;
  esac
done

URL="${1:?Usage: transcribe.sh <episode_url> [output.md]}"
EXPLICIT_OUTPUT="${2:-}"
TMPDIR="/tmp/xiaoyuzhou_$$"
AUDIO_BITRATE="64k"
OUTPUT=""

PROVIDER="${PROVIDER:-$(xy_get_provider)}"

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

for cmd in ffmpeg ffprobe curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: $cmd required" >&2; exit 1; }
done
mkdir -p "$TMPDIR"

ENGINE_NAME=""
DURATION_MIN=0
DURATION_SEC=0
TITLE=""
AUDIO_URL=""
DURATION=""
SUMMARY_PATH=""

fetch_episode_meta() {
  echo "==> Fetching episode page"
  PAGE=$(curl -sL "$URL" -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)")
  python3 - "$PAGE" > "$TMPDIR/meta.env" <<'PY'
import json, re, sys
html = sys.stdin.read()
title, audio_url, duration = "", "", ""
m = re.search(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', html, re.S)
if m:
    ep = json.loads(m.group(1))["props"]["pageProps"]["episode"]
    title = ep.get("title") or ""
    duration = str(ep.get("duration") or "")
    media = ep.get("media") or {}
    audio_url = (media.get("backupSource") or {}).get("url") or (ep.get("enclosure") or {}).get("url") or ""
if not audio_url:
    urls = re.findall(r'https://media\.xyzcdn\.net/[^"[:space:]]+\.(?:m4a|mp3|mp4a)', html)
    audio_url = urls[0] if urls else ""
if not title:
    tm = re.search(r'"title":"((?:\\.|[^"\\])*)"', html)
    if tm:
        title = json.loads(f'"{tm.group(1)}"')
print(f"AUDIO_URL={audio_url!r}")
print(f"TITLE={title!r}")
print(f"DURATION={duration!r}")
PY
  # shellcheck disable=SC1090
  source "$TMPDIR/meta.env"
  AUDIO_URL="${AUDIO_URL//\'/}"
  TITLE="${TITLE//\'/}"
  DURATION="${DURATION//\'/}"
  [[ -n "$AUDIO_URL" ]] || { echo "Error: cannot extract audio URL" >&2; exit 1; }
  [[ -n "$TITLE" ]] || TITLE="未命名播客"
  echo "    Title: $TITLE"
  echo "    Audio: $AUDIO_URL"
}

resolve_output_paths() {
  local out_dir
  out_dir="$(xy_ensure_output_dir)"
  if [[ -n "$EXPLICIT_OUTPUT" ]]; then
    OUTPUT="$EXPLICIT_OUTPUT"
  else
    OUTPUT=$(python3 "$SCRIPT_DIR/lib/paths.py" transcript-path "$out_dir" "$TITLE")
  fi
  SUMMARY_PATH=$(python3 "$SCRIPT_DIR/lib/paths.py" summary-for-transcript "$OUTPUT")
  mkdir -p "$(dirname "$OUTPUT")"
  echo "    Transcript file: $OUTPUT"
  echo "    Summary file:    $SUMMARY_PATH"
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
header = f"""---
title: "{title}"
type: transcript
source_url: "{url}"
duration: "{dm}分{ds}秒"
transcribed_at: {datetime.now().strftime('%Y-%m-%d %H:%M')}
engine: "{engine}"
---

# {title}

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

generate_and_save_summary() {
  local key model
  key="$(xy_get_dashscope_key)"
  if [[ -z "$key" ]]; then
    echo "Error: auto summary requires DashScope API key (configure.sh aliyun sk-...)" >&2
    echo "    Transcript saved; run save_summary.sh manually or configure aliyun key." >&2
    return 1
  fi
  model="$(xy_get_summary_model)"
  echo "==> Generating summary (DashScope $model)"
  python3 "$SCRIPT_DIR/summarize_transcript.py" \
    --api-key "$key" --model "$model" \
    --transcript "$OUTPUT" --title "$TITLE" \
    --output "$TMPDIR/summary_body.md"
  bash "$SCRIPT_DIR/save_summary.sh" --transcript "$OUTPUT" "$TMPDIR/summary_body.md"
}

fetch_episode_meta
resolve_output_paths
case "$PROVIDER" in
  aliyun) transcribe_aliyun ;;
  doubao) transcribe_doubao ;;
  siliconflow) transcribe_siliconflow ;;
  *) echo "Error: unknown provider '$PROVIDER'" >&2; exit 1 ;;
esac
merge_output
if [[ $SKIP_SUMMARY -eq 0 ]]; then
  if ! generate_and_save_summary; then
    echo "WARN: summary generation failed; transcript is saved at $OUTPUT" >&2
  fi
fi
xy_write_last_run "$OUTPUT" "$SUMMARY_PATH" "$TITLE" "$URL"
echo "==> Done"
echo "    Transcript: $OUTPUT"
echo "    Summary:    $SUMMARY_PATH"
