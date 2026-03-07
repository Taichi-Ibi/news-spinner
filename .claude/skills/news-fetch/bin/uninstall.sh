#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SPINNER_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"   # PROJECT/.claude/
PROJECT_ROOT="$(cd "$SPINNER_DIR/.." && pwd)"
RUNTIME_DIR="$SKILL_DIR/runtime"
SETTINGS="$SPINNER_DIR/settings.json"
GITIGNORE_FILE="$PROJECT_ROOT/.gitignore"

echo "=== NewsSpinner Uninstaller ==="

# 1. Clean up settings.json
if [ -f "$SETTINGS" ]; then
  latest_backup=$(ls -1t "$SETTINGS".bak.* 2>/dev/null | head -1 || true)
  if [ -n "$latest_backup" ]; then
    cp "$latest_backup" "$SETTINGS"
    echo "[1/3] settings.json restored from backup: $(basename "$latest_backup")"
  else
    cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
    jq '
      # Remove hook entries containing "rotate.sh" from UserPromptSubmit
      if .hooks.UserPromptSubmit then
        .hooks.UserPromptSubmit = [
          .hooks.UserPromptSubmit[] |
          select((.hooks // []) | all(.command // "" | contains("rotate.sh") | not))
        ]
      else . end |
      # Clean up empty arrays/objects
      if (.hooks.UserPromptSubmit // []) | length == 0 then del(.hooks.UserPromptSubmit) else . end |
      if (.hooks // {}) | length == 0 then del(.hooks) else . end |
      # Remove spinnerVerbs override
      del(.spinnerVerbs)
    ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "[1/3] No backup found; removed hook and spinnerVerbs from settings.json"
  fi
else
  echo "[1/3] settings.json not found, skipping"
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

# 2. Remove runtime data files (preserve runtime/config.json and skill files)
removed=()
for f in pool.json history.json .lock; do
  if [ -f "$RUNTIME_DIR/$f" ]; then
    rm "$RUNTIME_DIR/$f"
    removed+=("$f")
  fi
done
if [ "${#removed[@]}" -gt 0 ]; then
  echo "[2/4] Removed runtime data: ${removed[*]}"
else
  echo "[2/4] No runtime data files found, skipping"
fi

# 3. Restore .gitignore (remove NewsSpinner auto-added rules)
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

# 4. Remove skill directory itself
if [ -d "$SKILL_DIR" ]; then
  rm -rf "$SKILL_DIR"
  echo "[4/4] Removed skill directory: $SKILL_DIR"
else
  echo "[4/4] Skill directory not found, skipping"
fi

echo ""
echo "=== Uninstall complete! ==="
echo "Restart Claude Code to apply changes."
