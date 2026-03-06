#!/usr/bin/env bash
set -euo pipefail

SPINNER_DIR="${NEWSSPINNER_DIR:-$HOME/.newsspinner}"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== NewsSpinner Installer ==="

# 1. Check dependencies
missing=()
for cmd in jq curl; do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    missing+=("$cmd")
  fi
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "Error: missing required dependencies: ${missing[*]}" >&2
  echo "Please install them and try again." >&2
  exit 1
fi
echo "[1/7] Dependencies OK (jq, curl)"

# 2. Create directories
mkdir -p "$SPINNER_DIR/bin"
mkdir -p "$CLAUDE_DIR"
echo "[2/7] Directories created"

# 3. Copy scripts and set permissions
for script in fetch.sh rotate.sh install.sh uninstall.sh; do
  src="$SCRIPT_DIR/bin/$script"
  if [ -f "$src" ]; then
    cp "$src" "$SPINNER_DIR/bin/$script"
    chmod +x "$SPINNER_DIR/bin/$script"
  else
    echo "Warning: $src not found, skipping" >&2
  fi
done
echo "[3/7] Scripts installed to $SPINNER_DIR/bin/"

# 4. Create config.json (preserve existing)
if [ ! -f "$SPINNER_DIR/config.json" ]; then
  cp "$SCRIPT_DIR/config.json" "$SPINNER_DIR/config.json"
  echo "[4/7] Default config.json created"
else
  echo "[4/7] config.json already exists, keeping current"
fi

# 5. Initialize data files
[ -f "$SPINNER_DIR/pool.json" ]    || echo '[]' > "$SPINNER_DIR/pool.json"
[ -f "$SPINNER_DIR/history.json" ] || echo '[]' > "$SPINNER_DIR/history.json"
echo "[5/7] Data files initialized"

# 6. Install Claude Code skill
SKILL_DIR="$CLAUDE_DIR/skills/news-fetch"
mkdir -p "$SKILL_DIR"
if [ -f "$SCRIPT_DIR/SKILL.md" ]; then
  cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
  echo "[6/7] Skill /news-fetch installed"
else
  echo "[6/7] Warning: SKILL.md not found, skipping" >&2
fi

# 7. Register PostToolUse hook in settings.json
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"

if jq -e '.hooks.PostToolUse[]?.hooks[]? | select(.command | contains("newsspinner"))' "$SETTINGS" > /dev/null 2>&1; then
  echo "[7/7] NewsSpinner hook already registered"
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
  echo "[7/7] PostToolUse hook registered"
fi

# Optional: add initial keywords from arguments
if [ $# -gt 0 ]; then
  echo ""
  for keyword in "$@"; do
    bash "$SPINNER_DIR/bin/fetch.sh" add "$keyword"
  done
  echo ""
  echo "Running initial fetch..."
  bash "$SPINNER_DIR/bin/fetch.sh"
fi

echo ""
echo "=== Installation complete! ==="
echo ""
echo "Restart Claude Code to activate the hook."
echo ""
echo "Quick start:"
echo "  /news-fetch                               # manage feeds in Claude Code"
echo "  bash ~/.newsspinner/bin/fetch.sh add AI    # add a feed from shell"
echo "  bash ~/.newsspinner/bin/fetch.sh           # fetch headlines"
