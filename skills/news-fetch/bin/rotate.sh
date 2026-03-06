#!/usr/bin/env bash
set -euo pipefail

SPINNER_DIR="${NEWSSPINNER_DIR:-$HOME/.newsspinner}"
CONFIG="$SPINNER_DIR/config.json"
POOL="$SPINNER_DIR/pool.json"
HISTORY="$SPINNER_DIR/history.json"
LOCK="$SPINNER_DIR/.lock"
SETTINGS="$HOME/.claude/settings.json"

# Quick bail-outs for speed (this runs on every tool use)
[ -f "$POOL" ] || exit 0
[ -f "$SETTINGS" ] || exit 0
[ -f "$CONFIG" ] || exit 0

MAX_HISTORY=200

update_spinner() {
  local verbs_json="$1"
  # Read current settings, update only spinnerVerbs, write atomically
  jq --argjson sv "$verbs_json" '.spinnerVerbs = $sv' "$SETTINGS" > "$SETTINGS.tmp" \
    && mv "$SETTINGS.tmp" "$SETTINGS"
}

do_rotate() {
  local pool_size
  pool_size=$(jq 'length' "$POOL")

  if [ "$pool_size" -eq 0 ]; then
    # Pool empty: set empty_messages as verbs
    local empty_msgs
    empty_msgs=$(jq -r '.empty_messages // ["No news... refresh me"]' "$CONFIG")
    local verbs_json
    verbs_json=$(jq -n --argjson msgs "$empty_msgs" '{"mode": "replace", "verbs": $msgs}')
    update_spinner "$verbs_json"
    exit 0
  fi

  # Pick a random index
  local idx
  idx=$((RANDOM % pool_size))

  # Extract the title
  local title
  title=$(jq -r ".[$idx]" "$POOL")

  # Remove from pool
  jq "del(.[$idx])" "$POOL" > "$POOL.tmp" && mv "$POOL.tmp" "$POOL"

  # Add to history
  [ -f "$HISTORY" ] || echo '[]' > "$HISTORY"
  jq --arg t "$title" '. + [$t]' "$HISTORY" > "$HISTORY.tmp" && mv "$HISTORY.tmp" "$HISTORY"

  # Trim history to max
  local hist_size
  hist_size=$(jq 'length' "$HISTORY")
  if [ "$hist_size" -gt "$MAX_HISTORY" ]; then
    local trim=$((hist_size - MAX_HISTORY))
    jq ".[$trim:]" "$HISTORY" > "$HISTORY.tmp" && mv "$HISTORY.tmp" "$HISTORY"
  fi

  # Calculate remaining
  local remaining
  remaining=$(jq 'length' "$POOL")

  # Update spinner
  local display="${title} [${remaining}]"
  local verbs_json
  verbs_json=$(jq -n --arg v "$display" '{"mode": "replace", "verbs": [$v]}')
  update_spinner "$verbs_json"
}

# Use flock if available
if command -v flock > /dev/null 2>&1; then
  exec 9>"$LOCK"
  flock -w 5 9 || exit 0
  do_rotate
  exec 9>&-
else
  do_rotate
fi
