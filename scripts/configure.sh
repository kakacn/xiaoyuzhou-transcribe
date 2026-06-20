#!/usr/bin/env bash
# Configure API keys for xiaoyuzhou-transcribe.
#
# Usage:
#   configure.sh aliyun sk-xxx [--model fun-asr]
#   configure.sh doubao <api-key>
#   configure.sh doubao --legacy <app-key> <access-key>
#   configure.sh siliconflow sk-xxx [--model MODEL]
#   configure.sh default aliyun|doubao|siliconflow
#   configure.sh status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

usage() {
  cat <<'EOF'
Usage:
  configure.sh aliyun <sk-...> [--model fun-asr|paraformer-v2] [--summary-model qwen-long|qwen-plus]
  configure.sh doubao <api-key>
  configure.sh doubao --legacy <app-key> <access-key>
  configure.sh siliconflow <sk-...> [--model MODEL]
  configure.sh default <aliyun|doubao|siliconflow>
  configure.sh status

Keys:
  阿里云百炼  https://bailian.console.aliyun.com/
  豆包语音    https://console.volcengine.com/speech
  硅基流动    https://cloud.siliconflow.cn/account/ak
EOF
  exit "${1:-0}"
}

[[ $# -ge 1 ]] || usage 1
xy_ensure_config_dir

cmd="$1"
shift

case "$cmd" in
  aliyun)
    KEY="${1:?missing dashscope api key}"
    shift
    [[ "$KEY" =~ ^sk- ]] || { echo "Error: DashScope key should start with sk-" >&2; exit 1; }
    MODEL="fun-asr"
    SUMMARY_MODEL="qwen-long"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --model) MODEL="${2:?}"; shift 2 ;;
        --summary-model) SUMMARY_MODEL="${2:?}"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
      esac
    done
    printf '%s' "$KEY" > "$(xy_config_path dashscope_api_key)"
    chmod 600 "$(xy_config_path dashscope_api_key)"
    printf '%s' "$MODEL" > "$(xy_config_path dashscope_model)"
    printf '%s' "$SUMMARY_MODEL" > "$(xy_config_path summary_model)"
    printf '%s' "aliyun" > "$(xy_config_path provider)"
    echo "OK: Aliyun DashScope configured, asr_model=$MODEL summary_model=$SUMMARY_MODEL"
    ;;
  doubao)
    if [[ "${1:-}" == "--legacy" ]]; then
      shift
      APP="${1:?app key}"; ACCESS="${2:?access key}"; shift 2
      printf '%s' "$APP" > "$(xy_config_path volcengine_app_key)"
      printf '%s' "$ACCESS" > "$(xy_config_path volcengine_access_key)"
      chmod 600 "$(xy_config_path volcengine_app_key)" "$(xy_config_path volcengine_access_key)"
      rm -f "$(xy_config_path volcengine_api_key)"
      printf '%s' "doubao" > "$(xy_config_path provider)"
      echo "OK: Doubao legacy credentials configured"
    else
      KEY="${1:?missing volcengine api key}"
      printf '%s' "$KEY" > "$(xy_config_path volcengine_api_key)"
      chmod 600 "$(xy_config_path volcengine_api_key)"
      rm -f "$(xy_config_path volcengine_app_key)" "$(xy_config_path volcengine_access_key)"
      printf '%s' "doubao" > "$(xy_config_path provider)"
      echo "OK: Doubao API key configured (new console)"
    fi
    ;;
  siliconflow)
    KEY="${1:?missing siliconflow api key}"
    shift
    [[ "$KEY" =~ ^sk- ]] || { echo "Error: SiliconFlow key should start with sk-" >&2; exit 1; }
    MODEL="FunAudioLLM/SenseVoiceSmall"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --model) MODEL="${2:?}"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
      esac
    done
    printf '%s' "$KEY" > "$(xy_config_path siliconflow_api_key)"
    chmod 600 "$(xy_config_path siliconflow_api_key)"
    printf '%s' "$MODEL" > "$(xy_config_path siliconflow_model)"
    printf '%s' "siliconflow" > "$(xy_config_path provider)"
    echo "OK: SiliconFlow configured, model=$MODEL"
    ;;
  default)
    P="${1:?aliyun|doubao|siliconflow}"
    [[ "$P" == "aliyun" || "$P" == "doubao" || "$P" == "siliconflow" ]] || {
      echo "Error: unknown provider $P" >&2; exit 1
    }
    printf '%s' "$P" > "$(xy_config_path provider)"
    echo "OK: default provider=$P"
    ;;
  status)
    bash "$SCRIPT_DIR/check.sh" --all
    ;;
  -h|--help) usage 0 ;;
  *)
    echo "Error: unknown command '$cmd'" >&2
    usage 1
    ;;
esac
