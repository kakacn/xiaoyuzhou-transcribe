#!/usr/bin/env bash
# Shared config for xiaoyuzhou-transcribe

XIAOYUZHOU_CONFIG_DIR="${XIAOYUZHOU_CONFIG_DIR:-$HOME/.xiaoyuzhou-transcribe}"

xy_config_path() {
  echo "$XIAOYUZHOU_CONFIG_DIR/$1"
}

xy_ensure_config_dir() {
  mkdir -p "$XIAOYUZHOU_CONFIG_DIR"
  chmod 700 "$XIAOYUZHOU_CONFIG_DIR"
}

xy_read_file() {
  local f="$1"
  [[ -f "$f" ]] && tr -d '[:space:]' < "$f"
}

xy_get_provider() {
  local f
  f="$(xy_config_path provider)"
  if [[ -f "$f" ]]; then
    tr -d '[:space:]' < "$f"
  else
    echo "aliyun"
  fi
}

xy_get_dashscope_key() {
  [[ -n "${DASHSCOPE_API_KEY:-}" ]] && echo "$DASHSCOPE_API_KEY" && return
  xy_read_file "$(xy_config_path dashscope_api_key)"
}

xy_get_dashscope_model() {
  local v
  v="$(xy_read_file "$(xy_config_path dashscope_model)")"
  echo "${v:-fun-asr}"
}

# 豆包语音：新版控制台仅 X-Api-Key；旧版需 app_key + access_key
xy_get_volc_api_key() {
  [[ -n "${VOLCENGINE_API_KEY:-}" ]] && echo "$VOLCENGINE_API_KEY" && return
  xy_read_file "$(xy_config_path volcengine_api_key)"
}

xy_get_volc_app_key() {
  xy_read_file "$(xy_config_path volcengine_app_key)"
}

xy_get_volc_access_key() {
  xy_read_file "$(xy_config_path volcengine_access_key)"
}

xy_get_siliconflow_key() {
  [[ -n "${SILICONFLOW_API_KEY:-}" ]] && echo "$SILICONFLOW_API_KEY" && return
  xy_read_file "$(xy_config_path siliconflow_api_key)"
}

xy_get_siliconflow_model() {
  local v
  v="$(xy_read_file "$(xy_config_path siliconflow_model)")"
  echo "${v:-FunAudioLLM/SenseVoiceSmall}"
}

xy_provider_configured() {
  local p="$1"
  case "$p" in
    aliyun) [[ -n "$(xy_get_dashscope_key)" ]] ;;
    doubao)
      [[ -n "$(xy_get_volc_api_key)" ]] || {
        [[ -n "$(xy_get_volc_app_key)" && -n "$(xy_get_volc_access_key)" ]]
      }
      ;;
    siliconflow) [[ -n "$(xy_get_siliconflow_key)" ]] ;;
    *) return 1 ;;
  esac
}
