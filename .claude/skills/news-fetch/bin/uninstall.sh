#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SPINNER_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"   # PROJECT/.claude/
RUNTIME_DIR="$SKILL_DIR/runtime"
SETTINGS="$SPINNER_DIR/settings.json"

echo "=== NewsSpinner Uninstaller ==="

# 1. Clean up settings.json
if [ -f "$SETTINGS" ]; then
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
  echo "[1/2] Hook and spinnerVerbs removed from settings.json"
else
  echo "[1/2] settings.json not found, skipping"
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
  echo "[2/2] Removed runtime data: ${removed[*]}"
else
  echo "[2/2] No runtime data files found, skipping"
fi

echo ""
echo "=== Uninstall complete! ==="
echo "Restart Claude Code to apply changes."
