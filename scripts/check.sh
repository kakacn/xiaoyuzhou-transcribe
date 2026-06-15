#!/usr/bin/env bash
# Verify xiaoyuzhou-transcribe prerequisites.
# Prints OK or actionable error.

set -euo pipefail

fail() { echo "FAIL: $1" >&2; exit 1; }

command -v ffmpeg >/dev/null 2>&1 || fail "ffmpeg not found (brew install ffmpeg)"
command -v ffprobe >/dev/null 2>&1 || fail "ffprobe not found (brew install ffmpeg)"
command -v curl >/dev/null 2>&1 || fail "curl not found"
command -v python3 >/dev/null 2>&1 || fail "python3 not found"

KEY_FILE="$HOME/.xiaoyuzhou-transcribe/groq_api_key"
if [[ -z "${GROQ_API_KEY:-}" ]]; then
  [[ -f "$KEY_FILE" ]] || fail "Groq API Key not configured. Open https://console.groq.com/keys then run: bash scripts/configure.sh gsk_..."
  GROQ_API_KEY=$(tr -d '[:space:]' < "$KEY_FILE")
fi

[[ -n "$GROQ_API_KEY" ]] || fail "Empty Groq API Key"

HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${GROQ_API_KEY}" \
  https://api.groq.com/openai/v1/models)

case "$HTTP" in
  200) echo "OK: ffmpeg ready, Groq API key valid" ;;
  401) fail "Groq API key rejected (401). Create a new key at https://console.groq.com/keys" ;;
  429) echo "OK: ffmpeg ready, Groq key set (rate limited on probe, should still work)" ;;
  *) fail "Groq API probe returned HTTP $HTTP" ;;
esac
