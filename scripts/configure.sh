#!/usr/bin/env bash
# Save Groq API Key for xiaoyuzhou-transcribe skill.
# Usage: configure.sh <gsk_...>

set -euo pipefail

KEY="${1:?Usage: configure.sh <gsk_...>}"

if [[ ! "$KEY" =~ ^gsk_ ]]; then
  echo "Error: Groq API Key should start with gsk_" >&2
  exit 1
fi

CONFIG_DIR="$HOME/.xiaoyuzhou-transcribe"
KEY_FILE="$CONFIG_DIR/groq_api_key"
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"
printf '%s' "$KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"
echo "OK: Groq key saved to $KEY_FILE"
