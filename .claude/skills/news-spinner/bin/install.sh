#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SPINNER_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"   # PROJECT/.claude/
RUNTIME_DIR="$SKILL_DIR/runtime"
TEMPLATES_DIR="$SKILL_DIR/templates"
ROTATE_SH="$SCRIPT_DIR/rotate.sh"
SETTINGS="$SPINNER_DIR/settings.json"

echo "=== news-spinner Installer ==="

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

# 3. Initialize runtime directory from templates (preserve existing user files)
mkdir -p "$RUNTIME_DIR"
if [ ! -f "$RUNTIME_DIR/config.json" ]; then
  cp "$TEMPLATES_DIR/config.json" "$RUNTIME_DIR/config.json"
  echo "[3/4] runtime/config.json created from template"
else
  echo "[3/4] runtime/config.json already exists, keeping current"
fi
if [ ! -f "$RUNTIME_DIR/state.json" ]; then
  cp "$TEMPLATES_DIR/state.json" "$RUNTIME_DIR/state.json"
fi

# 4. Initialize runtime data files (migrate from legacy layout if needed)
[ -f "$SPINNER_DIR/pool.json" ]    && [ ! -f "$RUNTIME_DIR/pool.json" ]    && mv "$SPINNER_DIR/pool.json"    "$RUNTIME_DIR/pool.json"
[ -f "$SPINNER_DIR/history.json" ] && [ ! -f "$RUNTIME_DIR/history.json" ] && mv "$SPINNER_DIR/history.json" "$RUNTIME_DIR/history.json"
if [ ! -f "$RUNTIME_DIR/pool.json" ]; then
  cp "$TEMPLATES_DIR/ads.json" "$RUNTIME_DIR/pool.json"
  echo "[4/4] Spinner pool seeded with initial ads"
else
  echo "[4/4] pool.json already exists, keeping current"
fi
[ -f "$RUNTIME_DIR/history.json" ] || echo '[]' > "$RUNTIME_DIR/history.json"

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
  echo "[5/5] news-spinner hook already registered"
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
echo "  /news-spinner AI                               # fetch headlines for 'AI' in Claude Code"
echo "  bash \"$SCRIPT_DIR/fetch.sh\" AI               # fetch headlines from shell"
echo "  /news-spinner clear                            # clear the spinner pool"
