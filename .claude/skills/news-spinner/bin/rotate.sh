#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SPINNER_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"   # PROJECT/.claude/
RUNTIME_DIR="$SKILL_DIR/runtime"
CONFIG="$RUNTIME_DIR/config.json"
POOL="$RUNTIME_DIR/pool.json"
HISTORY="$RUNTIME_DIR/history.json"
LOCK="$RUNTIME_DIR/.lock"
SETTINGS="$SPINNER_DIR/settings.json"

mkdir -p "$RUNTIME_DIR"

# One-time migration from legacy .claude/*.json layout
[ -f "$SPINNER_DIR/config.json" ] && [ ! -f "$CONFIG" ] && mv "$SPINNER_DIR/config.json" "$CONFIG"
[ -f "$SPINNER_DIR/pool.json" ] && [ ! -f "$POOL" ] && mv "$SPINNER_DIR/pool.json" "$POOL"
[ -f "$SPINNER_DIR/history.json" ] && [ ! -f "$HISTORY" ] && mv "$SPINNER_DIR/history.json" "$HISTORY"

# Quick bail-outs for speed (this runs on every tool use)
[ -f "$POOL" ]     || exit 0
[ -f "$SETTINGS" ] || exit 0
[ -f "$CONFIG" ]   || exit 0

MAX_HISTORY=200

update_spinner() {
  local verbs_json="$1"
  jq --argjson sv "$verbs_json" '.spinnerVerbs = $sv' "$SETTINGS" \
    > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
}

do_rotate() {
  local pool_size
  pool_size=$(jq 'length' "$POOL")

  if [ "$pool_size" -eq 0 ]; then
    local empty_msgs
    empty_msgs=$(jq '.empty_messages // ["No news... run /news-fetch"]' "$CONFIG")
    update_spinner "$(jq -n --argjson msgs "$empty_msgs" '{"mode":"replace","verbs":$msgs}')"
    return 0
  fi

  # Pick a random index
  local idx title
  idx=$((RANDOM % pool_size))
  title=$(jq -r ".[$idx]" "$POOL")

  # Remove from pool, add to history, trim history — single jq pass each
  jq "del(.[$idx])" "$POOL" > "$POOL.tmp" && mv "$POOL.tmp" "$POOL"

  [ -f "$HISTORY" ] || echo '[]' > "$HISTORY"
  jq --arg t "$title" --argjson max "$MAX_HISTORY" '
    . + [$t] | if length > $max then .[(length - $max):] else . end
  ' "$HISTORY" > "$HISTORY.tmp" && mv "$HISTORY.tmp" "$HISTORY"

  update_spinner "$(jq -n --arg v "$title" '{"mode":"replace","verbs":[$v]}')"
}

# Use flock if available for safe concurrent access
if command -v flock > /dev/null 2>&1; then
  exec 9>"$LOCK"
  flock -w 5 9 || exit 0
  do_rotate
  exec 9>&-
else
  do_rotate
fi
