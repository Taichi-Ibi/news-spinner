#!/usr/bin/env bash
set -euo pipefail

SPINNER_DIR="${NEWSSPINNER_DIR:-$HOME/.newsspinner}"
SETTINGS="$HOME/.claude/settings.json"

echo "=== NewsSpinner Uninstaller ==="

# 1. Remove skill
SKILL_DIR="$HOME/.claude/skills/news-fetch"
if [ -d "$SKILL_DIR" ]; then
  rm -rf "$SKILL_DIR"
  echo "Skill /news-fetch removed"
fi

# 2. Update settings.json if it exists
if [ -f "$SETTINGS" ]; then
  # Backup
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  echo "settings.json backed up"

  # Remove hook entries containing "newsspinner" from PostToolUse
  jq '
    if .hooks.PostToolUse then
      .hooks.PostToolUse = [
        .hooks.PostToolUse[] |
        select(
          (.hooks // []) | all(.command // "" | contains("newsspinner") | not)
        )
      ]
    else . end |
    # Clean up empty PostToolUse array
    if (.hooks.PostToolUse // []) | length == 0 then del(.hooks.PostToolUse) else . end |
    # Clean up empty hooks object
    if (.hooks // {}) | length == 0 then del(.hooks) else . end |
    # Remove spinnerVerbs
    del(.spinnerVerbs)
  ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  echo "Hook and spinnerVerbs removed from settings.json"
else
  echo "settings.json not found, skipping"
fi

# 3. Remove NewsSpinner directory
if [ -d "$SPINNER_DIR" ]; then
  rm -rf "$SPINNER_DIR"
  echo "Removed $SPINNER_DIR"
else
  echo "$SPINNER_DIR not found, skipping"
fi

echo ""
echo "=== Uninstall complete! ==="
echo "Restart Claude Code to apply changes."
