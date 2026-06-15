#!/usr/bin/env bash
# Verify xiaoyuzhou-transcribe prerequisites.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }

command -v ffmpeg >/dev/null 2>&1 || fail "ffmpeg not found (brew install ffmpeg)"
command -v ffprobe >/dev/null 2>&1 || fail "ffprobe not found (brew install ffmpeg)"
command -v curl >/dev/null 2>&1 || fail "curl not found"
command -v python3 >/dev/null 2>&1 || fail "python3 not found"

PROVIDER="$(xy_get_provider)"

check_aliyun() {
  local key model
  key="$(xy_get_dashscope_key)"
  [[ -n "$key" ]] || fail "DashScope API Key not configured. Run: bash scripts/configure.sh aliyun sk-..."
  model="$(xy_get_dashscope_model)"
  # lightweight probe: models list
  local http
  http=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${key}" \
    "https://dashscope.aliyuncs.com/api/v1/models")
  case "$http" in
    200) echo "OK: ffmpeg ready, provider=aliyun, model=$model, DashScope API key valid" ;;
    401|403) fail "DashScope API key rejected ($http). Get key at https://bailian.console.aliyun.com/" ;;
    *) echo "OK: ffmpeg ready, provider=aliyun, model=$model, DashScope key set (probe HTTP $http)" ;;
  esac
}

check_groq() {
  local key
  key="$(xy_get_groq_key)"
  [[ -n "$key" ]] || fail "Groq API Key not configured. Run: bash scripts/configure.sh groq gsk_..."
  local http
  http=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${key}" \
    https://api.groq.com/openai/v1/models)
  case "$http" in
    200) echo "OK: ffmpeg ready, provider=groq, Groq API key valid" ;;
    401) fail "Groq API key rejected (401)" ;;
    429) echo "OK: ffmpeg ready, provider=groq, Groq key set (rate limited on probe)" ;;
    *) fail "Groq API probe returned HTTP $http" ;;
  esac
}

case "$PROVIDER" in
  aliyun) check_aliyun ;;
  groq) check_groq ;;
  *) fail "unknown provider '$PROVIDER' in $(xy_config_path provider)" ;;
esac

# show fallback availability
if [[ "$PROVIDER" == "aliyun" ]] && [[ -n "$(xy_get_groq_key)" ]]; then
  echo "    fallback: groq key also configured"
elif [[ "$PROVIDER" == "groq" ]] && [[ -n "$(xy_get_dashscope_key)" ]]; then
  echo "    fallback: aliyun key also configured"
fi
