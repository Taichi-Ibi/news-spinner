#!/usr/bin/env bash
set -euo pipefail

SPINNER_DIR="${NEWSSPINNER_DIR:-$HOME/.newsspinner}"
SETTINGS="$HOME/.claude/settings.json"

echo "=== JokeAds Uninstaller ==="

# 1. Remove Claude Code skill
SKILL_DIR="$HOME/.claude/skills/joke-ads"
if [ -d "$SKILL_DIR" ]; then
  rm -rf "$SKILL_DIR"
  echo "[1/3] Skill /ad removed"
else
  echo "[1/3] Skill directory not found, skipping"
fi

# 2. Clean up settings.json
if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"

  jq '
    # Remove hook entries containing "newsspinner"
    if .hooks.PostToolUse then
      .hooks.PostToolUse = [
        .hooks.PostToolUse[] |
        select((.hooks // []) | all(.command // "" | contains("newsspinner") | not))
      ]
    else . end |
    # Clean up empty arrays/objects
    if (.hooks.PostToolUse // []) | length == 0 then del(.hooks.PostToolUse) else . end |
    if (.hooks // {}) | length == 0 then del(.hooks) else . end |
    # Remove spinnerVerbs override
    del(.spinnerVerbs)
  ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  echo "[2/3] Hook and spinnerVerbs removed from settings.json"
else
  echo "[2/3] settings.json not found, skipping"
fi

# 3. Remove data directory
if [ -d "$SPINNER_DIR" ]; then
  rm -rf "$SPINNER_DIR"
  echo "[3/3] Removed $SPINNER_DIR"
else
  echo "[3/3] $SPINNER_DIR not found, skipping"
fi

echo ""
echo "=== Uninstall complete! ==="
echo "広告のない世界へようこそ。…でも本当にそれでいいんですか？"
echo "Restart Claude Code to apply changes."
