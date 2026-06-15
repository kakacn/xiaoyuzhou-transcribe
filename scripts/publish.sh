#!/usr/bin/env bash
# Create GitHub repo (if needed) and push main branch.
# Requires: gh auth login OR GH_TOKEN / GITHUB_TOKEN in environment.

set -euo pipefail

REPO="kakacn/xiaoyuzhou-transcribe"
DESC="Agent Skill: transcribe Xiaoyuzhou (小宇宙) podcasts to Markdown via Groq Whisper"

cd "$(dirname "$0")/.."

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: not a git repository" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  if [[ -z "${GH_TOKEN:-}" && -z "${GITHUB_TOKEN:-}" ]]; then
    echo "GitHub CLI not authenticated." >&2
    echo "Run:  gh auth login" >&2
    echo "Or:   export GH_TOKEN=ghp_..." >&2
    exit 1
  fi
fi

if ! gh repo view "$REPO" >/dev/null 2>&1; then
  echo "Creating $REPO ..."
  gh repo create "$REPO" --public --description "$DESC" --source=. --remote=origin --push
else
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "git@github.com:${REPO}.git"
  git push -u origin main
fi

echo "Published: https://github.com/${REPO}"
