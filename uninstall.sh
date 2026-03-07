#!/usr/bin/env bash
# NewsSpinner — one-liner uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/Taichi-Ibi/NewsSpinner/main/uninstall.sh | bash
set -euo pipefail

PROJECT_ROOT="$(pwd)"
CLAUDE_DIR="${PROJECT_ROOT}/.claude"
SKILL_DIR="${CLAUDE_DIR}/skills/news-fetch"
SKILL_UNINSTALL="${SKILL_DIR}/bin/uninstall.sh"
SETTINGS="${CLAUDE_DIR}/settings.json"
GITIGNORE_FILE="${PROJECT_ROOT}/.gitignore"

echo "=== NewsSpinner Uninstaller ==="
echo "[1/4] Using project directory: ${PROJECT_ROOT}"

if [ -f "$SKILL_UNINSTALL" ]; then
  echo "[2/4] Running news-fetch uninstaller..."
  bash "$SKILL_UNINSTALL"
else
  latest_backup=$(ls -1t "$SETTINGS".bak.* 2>/dev/null | head -1 || true)
  if [ -n "$latest_backup" ]; then
    cp "$latest_backup" "$SETTINGS"
    echo "[2/4] Restored settings.json from backup: $(basename "$latest_backup")"
  else
    echo "[2/4] news-fetch uninstall script not found and no settings backup found"
  fi
fi

# Remove empty-object backup files (legacy "{}" backups)
removed_empty_baks=0
for bak in "$SETTINGS".bak.*; do
  [ -f "$bak" ] || continue
  if jq -e 'type == "object" and length == 0' "$bak" > /dev/null 2>&1; then
    rm -f "$bak"
    removed_empty_baks=$((removed_empty_baks + 1))
  fi
done
if [ "$removed_empty_baks" -gt 0 ]; then
  echo "      Removed empty settings backups: $removed_empty_baks"
fi

# Restore .gitignore even if skill uninstall script is missing
gitignore_rules=(
  "# NewsSpinner (auto-added)"
  ".claude/skills/news-fetch/"
  ".claude/skills/news-fetch/runtime/config.json"
  ".claude/skills/news-fetch/runtime/pool.json"
  ".claude/skills/news-fetch/runtime/history.json"
  ".claude/skills/news-fetch/runtime/.lock"
  ".claude/settings.json"
  ".claude/settings.json.bak.*"
)

if [ -f "$GITIGNORE_FILE" ]; then
  tmp="$GITIGNORE_FILE.tmp"
  cp "$GITIGNORE_FILE" "$tmp"
  removed_rules=0
  for rule in "${gitignore_rules[@]}"; do
    next="${tmp}.next"
    if grep -Fqx "$rule" "$tmp"; then
      grep -Fvx "$rule" "$tmp" > "$next" || true
      mv "$next" "$tmp"
      removed_rules=$((removed_rules + 1))
    fi
  done
  mv "$tmp" "$GITIGNORE_FILE"
  echo "[3/4] .gitignore restored (${removed_rules} rule(s) removed)"
else
  echo "[3/4] .gitignore not found, skipping"
fi

if [ -d "$SKILL_DIR" ]; then
  rm -rf "$SKILL_DIR"
  echo "[4/4] Removed skill directory: .claude/skills/news-fetch"
else
  echo "[4/4] Skill directory not found, skipping"
fi

echo ""
echo "=== Uninstall complete! ==="
echo "Restart Claude Code to apply changes."
