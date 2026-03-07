#!/usr/bin/env bash
# NewsSpinner — one-liner uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/Taichi-Ibi/NewsSpinner/main/uninstall.sh | bash
set -euo pipefail

PROJECT_ROOT="$(pwd)"
CLAUDE_DIR="${PROJECT_ROOT}/.claude"
SKILL_DIR="${CLAUDE_DIR}/skills/news-fetch"
SKILL_UNINSTALL="${SKILL_DIR}/bin/uninstall.sh"

echo "=== NewsSpinner Uninstaller ==="
echo "[1/3] Using project directory: ${PROJECT_ROOT}"

if [ -f "$SKILL_UNINSTALL" ]; then
  echo "[2/3] Running news-fetch uninstaller..."
  bash "$SKILL_UNINSTALL"
else
  echo "[2/3] news-fetch uninstall script not found, skipping hook cleanup"
fi

if [ -d "$SKILL_DIR" ]; then
  rm -rf "$SKILL_DIR"
  echo "[3/3] Removed skill directory: .claude/skills/news-fetch"
else
  echo "[3/3] Skill directory not found, skipping"
fi

echo ""
echo "=== Uninstall complete! ==="
echo "Restart Claude Code to apply changes."
