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
  if [[ -n "${DASHSCOPE_API_KEY:-}" ]]; then
    echo "$DASHSCOPE_API_KEY"
    return
  fi
  local f
  f="$(xy_config_path dashscope_api_key)"
  [[ -f "$f" ]] && tr -d '[:space:]' < "$f"
}

xy_get_groq_key() {
  if [[ -n "${GROQ_API_KEY:-}" ]]; then
    echo "$GROQ_API_KEY"
    return
  fi
  local f
  f="$(xy_config_path groq_api_key)"
  [[ -f "$f" ]] && tr -d '[:space:]' < "$f"
}

xy_get_dashscope_model() {
  local f
  f="$(xy_config_path dashscope_model)"
  if [[ -f "$f" ]]; then
    tr -d '[:space:]' < "$f"
  else
    echo "fun-asr"
  fi
}
