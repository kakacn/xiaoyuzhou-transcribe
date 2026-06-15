#!/usr/bin/env bash
# Verify xiaoyuzhou-transcribe prerequisites.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }

SHOW_ALL=0
[[ "${1:-}" == "--all" || "${1:-}" == "status" ]] && SHOW_ALL=1

command -v ffmpeg >/dev/null 2>&1 || fail "ffmpeg not found (brew install ffmpeg)"
command -v ffprobe >/dev/null 2>&1 || fail "ffprobe not found"
command -v curl >/dev/null 2>&1 || fail "curl not found"
command -v python3 >/dev/null 2>&1 || fail "python3 not found"

status_line() {
  local name="$1" configured="$2" detail="${3:-}"
  if [[ "$configured" == "yes" ]]; then
    echo "  [OK]   $name${detail:+ — $detail}"
  else
    echo "  [MISS] $name"
  fi
}

any_configured=0
for p in aliyun minimax doubao siliconflow; do
  xy_provider_configured "$p" && any_configured=1
done

if [[ $SHOW_ALL -eq 1 ]]; then
  echo "==> Provider keys (~/.xiaoyuzhou-transcribe/)"
  echo "    default: $(xy_get_provider)"
  echo ""
  for p in aliyun minimax doubao siliconflow; do
    if xy_provider_configured "$p"; then
      case "$p" in
        aliyun) status_line "$p" yes "model=$(xy_get_dashscope_model)" ;;
        minimax) status_line "$p" yes "key set（转写待官方 ASR）" ;;
        doubao)
          if [[ -n "$(xy_get_volc_api_key)" ]]; then
            status_line "$p" yes "new-console"
          else
            status_line "$p" yes "legacy"
          fi
          ;;
        siliconflow) status_line "$p" yes "model=$(xy_get_siliconflow_model)" ;;
      esac
    else
      status_line "$p" no
    fi
  done
  echo ""
  [[ $any_configured -eq 1 ]] || fail "未配置任何后端 Key，请先运行 configure.sh"
  exit 0
fi

PROVIDER="$(xy_get_provider)"
case "$PROVIDER" in
  aliyun)
    key="$(xy_get_dashscope_key)"
    [[ -n "$key" ]] || fail "DashScope key missing. Run: configure.sh aliyun sk-..."
    model="$(xy_get_dashscope_model)"
    http=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${key}" \
      "https://dashscope.aliyuncs.com/api/v1/models")
    case "$http" in
      200) echo "OK: provider=aliyun, model=$model, DashScope key valid" ;;
      401|403) fail "DashScope key rejected ($http)" ;;
      *) echo "OK: provider=aliyun, model=$model, key set (probe HTTP $http)" ;;
    esac
    ;;
  minimax)
    key="$(xy_get_minimax_key)"
    [[ -n "$key" ]] || fail "MiniMax key missing. Run: configure.sh minimax sk-..."
    http=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${key}" \
      "https://api.minimaxi.com/v1/models")
    case "$http" in
      200) echo "OK: provider=minimax, key valid（转写请改用 aliyun/doubao/siliconflow）" ;;
      401|403) fail "MiniMax key rejected ($http)" ;;
      *) echo "OK: provider=minimax, key set (probe HTTP $http)" ;;
    esac
    ;;
  doubao)
    api="$(xy_get_volc_api_key)"; app="$(xy_get_volc_app_key)"; acc="$(xy_get_volc_access_key)"
    if [[ -n "$api" ]]; then
      echo "OK: provider=doubao, mode=new-console (X-Api-Key configured)"
    elif [[ -n "$app" && -n "$acc" ]]; then
      echo "OK: provider=doubao, mode=legacy (app_key + access_key)"
    else
      fail "Doubao credentials missing. Run: configure.sh doubao <api-key>"
    fi
    ;;
  siliconflow)
    key="$(xy_get_siliconflow_key)"
    [[ -n "$key" ]] || fail "SiliconFlow key missing. Run: configure.sh siliconflow sk-..."
    model="$(xy_get_siliconflow_model)"
    http=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${key}" \
      "https://api.siliconflow.cn/v1/models")
    case "$http" in
      200) echo "OK: provider=siliconflow, model=$model, key valid" ;;
      401|403) fail "SiliconFlow key rejected ($http)" ;;
      *) echo "OK: provider=siliconflow, model=$model, key set (probe HTTP $http)" ;;
    esac
    ;;
  *) fail "unknown provider '$PROVIDER'" ;;
esac
