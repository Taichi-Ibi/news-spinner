#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SPINNER_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"   # PROJECT/.claude/
RUNTIME_DIR="$SKILL_DIR/runtime"
ROTATE_SH="$SCRIPT_DIR/rotate.sh"
SETTINGS="$SPINNER_DIR/settings.json"

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
echo "[1/4] Dependencies OK (jq, curl)"

# 2. Set execute permissions on scripts
chmod +x "$SCRIPT_DIR"/*.sh
echo "[2/4] Script permissions set"

# 3. Create runtime config.json (preserve existing)
mkdir -p "$RUNTIME_DIR"
if [ -f "$SPINNER_DIR/config.json" ] && [ ! -f "$RUNTIME_DIR/config.json" ]; then
  mv "$SPINNER_DIR/config.json" "$RUNTIME_DIR/config.json"
  echo "[3/4] Migrated legacy .claude/config.json -> news-fetch/runtime/config.json"
elif [ ! -f "$RUNTIME_DIR/config.json" ]; then
  cp "$SKILL_DIR/config.json" "$RUNTIME_DIR/config.json"
  echo "[3/4] Default runtime/config.json created"
else
  echo "[3/4] runtime/config.json already exists, keeping current"
fi

# 4. Initialize runtime data files
if [ -f "$SPINNER_DIR/pool.json" ] && [ ! -f "$RUNTIME_DIR/pool.json" ]; then
  mv "$SPINNER_DIR/pool.json" "$RUNTIME_DIR/pool.json"
fi
if [ -f "$SPINNER_DIR/history.json" ] && [ ! -f "$RUNTIME_DIR/history.json" ]; then
  mv "$SPINNER_DIR/history.json" "$RUNTIME_DIR/history.json"
fi
[ -f "$RUNTIME_DIR/pool.json" ]    || echo '[]' > "$RUNTIME_DIR/pool.json"
[ -f "$RUNTIME_DIR/history.json" ] || echo '[]' > "$RUNTIME_DIR/history.json"
echo "[4/4] Data files initialized"

# 5. Register UserPromptSubmit hook in project settings.json
settings_created=false
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
  settings_created=true
fi

if [ "$settings_created" = false ]; then
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
fi

if jq -e '.hooks.UserPromptSubmit[]?.hooks[]? | select(.command | contains("rotate.sh"))' "$SETTINGS" > /dev/null 2>&1; then
  echo "[5/5] NewsSpinner hook already registered"
else
  jq --arg cmd "$ROTATE_SH 2>/dev/null || true" '
    .hooks //= {} |
    .hooks.UserPromptSubmit //= [] |
    .hooks.UserPromptSubmit += [
      {
        "hooks": [
          {
            "type": "command",
            "command": $cmd
          }
        ]
      }
    ]
  ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  echo "[5/5] UserPromptSubmit hook registered"
fi

# Optional: add initial keywords from arguments
if [ $# -gt 0 ]; then
  echo ""
  for keyword in "$@"; do
    bash "$SCRIPT_DIR/fetch.sh" add "$keyword"
  done
  echo ""
  echo "Running initial fetch..."
  bash "$SCRIPT_DIR/fetch.sh"
fi

echo ""
echo "=== Installation complete! ==="
echo ""
echo "Restart Claude Code to activate the hook."
echo ""
echo "Quick start:"
echo "  /news-fetch                                    # manage feeds in Claude Code"
echo "  bash \"$SCRIPT_DIR/fetch.sh\" add AI            # add a feed from shell"
echo "  bash \"$SCRIPT_DIR/fetch.sh\"                   # fetch headlines"
