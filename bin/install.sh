#!/usr/bin/env bash
set -euo pipefail

SPINNER_DIR="${NEWSSPINNER_DIR:-$HOME/.newsspinner}"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== NewsSpinner Installer ==="

# 1. Check dependencies
for cmd in jq curl; do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    echo "Error: '$cmd' is required but not found. Please install it." >&2
    exit 1
  fi
done
echo "Dependencies OK (jq, curl)"

# 2. Create directories
mkdir -p "$SPINNER_DIR/bin"
mkdir -p "$CLAUDE_DIR"
echo "Directories created"

# 3. Copy scripts and set permissions
for script in fetch.sh rotate.sh install.sh uninstall.sh; do
  if [ -f "$SCRIPT_DIR/bin/$script" ]; then
    cp "$SCRIPT_DIR/bin/$script" "$SPINNER_DIR/bin/$script"
    chmod +x "$SPINNER_DIR/bin/$script"
  fi
done
echo "Scripts installed"

# 4. Create config.json if not exists
if [ ! -f "$SPINNER_DIR/config.json" ]; then
  cp "$SCRIPT_DIR/config.json" "$SPINNER_DIR/config.json"
  echo "Default config.json created"
else
  echo "config.json already exists, skipping"
fi

# 5. Initialize pool.json and history.json
[ -f "$SPINNER_DIR/pool.json" ] || echo '[]' > "$SPINNER_DIR/pool.json"
[ -f "$SPINNER_DIR/history.json" ] || echo '[]' > "$SPINNER_DIR/history.json"
echo "pool.json and history.json initialized"

# 6. Install Claude Code skill
SKILL_DIR="$CLAUDE_DIR/skills/news-fetch"
mkdir -p "$SKILL_DIR"
if [ -f "$SCRIPT_DIR/skills/news-fetch/SKILL.md" ]; then
  cp "$SCRIPT_DIR/skills/news-fetch/SKILL.md" "$SKILL_DIR/SKILL.md"
  echo "Skill /news-fetch installed"
fi

# 7. Add PostToolUse hook to settings.json
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

# Backup settings
cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
echo "settings.json backed up"

# Check if newsspinner hook already exists
if jq -e '.hooks.PostToolUse[]?.hooks[]? | select(.command | contains("newsspinner"))' "$SETTINGS" > /dev/null 2>&1; then
  echo "NewsSpinner hook already registered, skipping"
else
  jq '
    .hooks //= {} |
    .hooks.PostToolUse //= [] |
    .hooks.PostToolUse += [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.newsspinner/bin/rotate.sh 2>/dev/null || true"
          }
        ]
      }
    ]
  ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  echo "PostToolUse hook registered"
fi

# 8. Add initial keywords if provided as arguments
if [ $# -gt 0 ]; then
  for keyword in "$@"; do
    bash "$SPINNER_DIR/bin/fetch.sh" add "$keyword"
  done
  echo ""
  echo "Running initial fetch..."
  bash "$SPINNER_DIR/bin/fetch.sh"
else
  echo ""
  echo "No keywords provided. Add feeds with:"
  echo "  bash ~/.newsspinner/bin/fetch.sh add <keyword>"
  echo "Or use /news-fetch in Claude Code."
fi

echo ""
echo "=== Installation complete! ==="
echo "Restart Claude Code to activate the hook."
echo ""
echo "Usage:"
echo "  /news-fetch             # Manage feeds from Claude Code"
echo "  bash ~/.newsspinner/bin/fetch.sh add AI     # Add a feed"
echo "  bash ~/.newsspinner/bin/fetch.sh             # Fetch headlines"
echo "  bash ~/.newsspinner/bin/uninstall.sh         # Remove NewsSpinner"
