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

# Remember last install path for setup hints
LAST_INSTALL="${base_global}/.xiaoyuzhou-transcribe/last_install_dir"
mkdir -p "$(dirname "$LAST_INSTALL")"
if [[ "$SCOPE" == "global" ]]; then
  case "$AGENT" in
    cursor) printf '%s' "$base_global/.cursor/skills/$SKILL_NAME" > "$LAST_INSTALL" ;;
    claude) printf '%s' "$base_global/.claude/skills/$SKILL_NAME" > "$LAST_INSTALL" ;;
    all) printf '%s' "$base_global/.claude/skills/$SKILL_NAME" > "$LAST_INSTALL" ;;
    *) printf '%s' "$base_project/.claude/skills/$SKILL_NAME" > "$LAST_INSTALL" 2>/dev/null || true ;;
  esac
else
  printf '%s' "$base_project/.claude/skills/$SKILL_NAME" > "$LAST_INSTALL" 2>/dev/null || \
    printf '%s' "$base_project/skills/$SKILL_NAME" > "$LAST_INSTALL" 2>/dev/null || true
fi

HINT_SCRIPT=""
for d in \
  "$base_global/.claude/skills/$SKILL_NAME/scripts/setup-hint.sh" \
  "$base_project/.claude/skills/$SKILL_NAME/scripts/setup-hint.sh" \
  "$base_project/skills/$SKILL_NAME/scripts/setup-hint.sh"; do
  if [[ -f "$d" ]]; then HINT_SCRIPT="$d"; break; fi
done

if [[ -n "$HINT_SCRIPT" ]]; then
  bash "$HINT_SCRIPT"
else
  echo ""
  echo "Done. Next: configure API Key — aliyun | doubao | siliconflow"
  echo "  bash <skill-dir>/scripts/configure.sh aliyun sk_YOUR_KEY"
fi
