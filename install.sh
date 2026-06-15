#!/usr/bin/env bash
# Install xiaoyuzhou-transcribe skill for AI coding agents.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kakacn/xiaoyuzhou-transcribe/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --global --agent openclaw
#
# Options:
#   -g, --global     Install to user home (default: project)
#   -a, --agent      cursor | claude | codex | opencode | openclaw | all (default: all)
#   -y, --yes        Non-interactive
#   --copy           Copy repo instead of shallow clone

set -euo pipefail

SKILL_NAME="xiaoyuzhou-transcribe"
REPO="${SKILL_REPO:-https://github.com/kakacn/xiaoyuzhou-transcribe.git}"
BRANCH="${SKILL_BRANCH:-main}"
SCOPE="project"
AGENT="all"
YES=0
USE_COPY=0

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--global) SCOPE="global"; shift ;;
    -a|--agent) AGENT="${2:?}"; shift 2 ;;
    -y|--yes) YES=1; shift ;;
    --copy) USE_COPY=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

install_one() {
  local agent="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"

  if [[ "$USE_COPY" -eq 1 ]]; then
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN
    git clone --depth 1 --branch "$BRANCH" "$REPO" "$tmp/repo" >/dev/null 2>&1
    cp -R "$tmp/repo/." "$dest"
    chmod +x "$dest/scripts/"*.sh 2>/dev/null || true
    echo "Installed ($agent): $dest"
    return
  fi

  git clone --depth 1 --branch "$BRANCH" "$REPO" "$dest"
  chmod +x "$dest/scripts/"*.sh 2>/dev/null || true
  echo "Installed ($agent): $dest"
}

base_global="$HOME"
base_project="${PWD}"

targets=()
case "$AGENT" in
  cursor) targets=("cursor") ;;
  claude) targets=("claude") ;;
  codex) targets=("codex") ;;
  opencode) targets=("opencode") ;;
  openclaw) targets=("openclaw") ;;
  all) targets=("cursor" "claude" "codex" "opencode" "openclaw") ;;
  *) echo "Unknown agent: $AGENT" >&2; exit 1 ;;
esac

for t in "${targets[@]}"; do
  case "$SCOPE" in
    global)
      case "$t" in
        cursor) install_one cursor "$base_global/.cursor/skills/$SKILL_NAME" ;;
        claude) install_one claude "$base_global/.claude/skills/$SKILL_NAME" ;;
        codex) install_one codex "$base_global/.codex/skills/$SKILL_NAME" ;;
        opencode) install_one opencode "$base_global/.opencode/skills/$SKILL_NAME" ;;
        openclaw) install_one openclaw "$base_global/.openclaw/skills/$SKILL_NAME" ;;
      esac
      ;;
    project)
      case "$t" in
        cursor) install_one cursor "$base_project/.cursor/skills/$SKILL_NAME" ;;
        claude) install_one claude "$base_project/.claude/skills/$SKILL_NAME" ;;
        codex) install_one codex "$base_project/.codex/skills/$SKILL_NAME" ;;
        opencode) install_one opencode "$base_project/.opencode/skills/$SKILL_NAME" ;;
        openclaw) install_one openclaw "$base_project/skills/$SKILL_NAME" ;;
      esac
      ;;
  esac
done

echo ""
echo "Done. Next steps:"
echo "  1. Install ffmpeg if needed:  brew install ffmpeg"
echo "  2. Get a free Groq API Key:  https://console.groq.com/keys"
echo "  3. Configure:"
echo "       bash <install-dir>/scripts/configure.sh gsk_YOUR_KEY"
echo "  4. Verify:"
echo "       bash <install-dir>/scripts/check.sh"
echo ""
echo "Then restart your AI tool and try:"
echo "  帮我把这期小宇宙播客转成逐字稿 https://www.xiaoyuzhoufm.com/episode/EPISODE_ID"
