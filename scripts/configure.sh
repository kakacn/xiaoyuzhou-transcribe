#!/usr/bin/env bash
# Configure API keys and default provider for xiaoyuzhou-transcribe.
#
# Usage:
#   configure.sh aliyun sk-xxxxxxxx [--model fun-asr]
#   configure.sh groq gsk_xxxxxxxx
#   configure.sh default aliyun|groq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

usage() {
  cat <<'EOF'
Usage:
  configure.sh aliyun <sk-...> [--model fun-asr|paraformer-v2]
  configure.sh groq <gsk-...>
  configure.sh default <aliyun|groq>

Aliyun key: https://bailian.console.aliyun.com/ → API Key
Groq key:   https://console.groq.com/keys
EOF
  exit "${1:-0}"
}

[[ $# -ge 1 ]] || usage 1

xy_ensure_config_dir

cmd="$1"
shift

# Legacy: configure.sh sk-xxx / gsk_xxx
if [[ "$cmd" =~ ^sk- ]]; then
  xy_ensure_config_dir
  printf '%s' "$cmd" > "$(xy_config_path dashscope_api_key)"
  chmod 600 "$(xy_config_path dashscope_api_key)"
  printf '%s' "fun-asr" > "$(xy_config_path dashscope_model)"
  printf '%s' "aliyun" > "$(xy_config_path provider)"
  echo "OK: DashScope key saved, default provider=aliyun"
  exit 0
fi
if [[ "$cmd" =~ ^gsk_ ]]; then
  xy_ensure_config_dir
  printf '%s' "$cmd" > "$(xy_config_path groq_api_key)"
  chmod 600 "$(xy_config_path groq_api_key)"
  printf '%s' "groq" > "$(xy_config_path provider)"
  echo "OK: Groq key saved, default provider=groq"
  exit 0
fi

case "$cmd" in
  aliyun)
    KEY="${1:?missing dashscope api key (sk-...)}"
    shift
    [[ "$KEY" =~ ^sk- ]] || { echo "Error: DashScope API Key should start with sk-" >&2; exit 1; }
    MODEL="fun-asr"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --model) MODEL="${2:?}"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
      esac
    done
    printf '%s' "$KEY" > "$(xy_config_path dashscope_api_key)"
    chmod 600 "$(xy_config_path dashscope_api_key)"
    printf '%s' "$MODEL" > "$(xy_config_path dashscope_model)"
    chmod 600 "$(xy_config_path dashscope_model)"
    printf '%s' "aliyun" > "$(xy_config_path provider)"
    echo "OK: DashScope key saved, model=$MODEL, default provider=aliyun"
    ;;
  groq)
    KEY="${1:?missing groq api key (gsk-...)}"
    [[ "$KEY" =~ ^gsk_ ]] || { echo "Error: Groq API Key should start with gsk_" >&2; exit 1; }
    printf '%s' "$KEY" > "$(xy_config_path groq_api_key)"
    chmod 600 "$(xy_config_path groq_api_key)"
    if [[ ! -f "$(xy_config_path provider)" ]]; then
      printf '%s' "groq" > "$(xy_config_path provider)"
    fi
    echo "OK: Groq key saved"
    ;;
  default)
    P="${1:?aliyun or groq}"
    [[ "$P" == "aliyun" || "$P" == "groq" ]] || { echo "Error: provider must be aliyun or groq" >&2; exit 1; }
    printf '%s' "$P" > "$(xy_config_path provider)"
    echo "OK: default provider=$P"
    ;;
  -h|--help)
    usage 0
    ;;
  *)
    echo "Error: unknown command '$cmd'" >&2
    usage 1
    ;;
esac
