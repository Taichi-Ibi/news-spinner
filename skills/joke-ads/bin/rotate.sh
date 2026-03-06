#!/usr/bin/env bash
set -euo pipefail

SPINNER_DIR="${NEWSSPINNER_DIR:-$HOME/.newsspinner}"
CONFIG="$SPINNER_DIR/config.json"
POOL="$SPINNER_DIR/pool.json"
HISTORY="$SPINNER_DIR/history.json"
LOCK="$SPINNER_DIR/.lock"

# Quick bail-outs for speed (this runs on every tool use)
[ -f "$POOL" ]   || exit 0
[ -f "$CONFIG" ] || exit 0

MAX_HISTORY=200

do_rotate() {
  local pool_size
  pool_size=$(jq 'length' "$POOL")

  if [ "$pool_size" -eq 0 ]; then
    local empty_msgs
    empty_msgs=$(jq -c '.empty_messages // ["広告枠空いてます！ /ad load で補充"]' "$CONFIG")
    jq -n --argjson msgs "$empty_msgs" '{"spinnerVerbs":{"mode":"replace","verbs":$msgs}}'
    return 0
  fi

  # Pick a random ad
  local idx title
  idx=$((RANDOM % pool_size))
  title=$(jq -r ".[$idx]" "$POOL")

  # Remove from pool, add to history
  jq "del(.[$idx])" "$POOL" > "$POOL.tmp" && mv "$POOL.tmp" "$POOL"

  [ -f "$HISTORY" ] || echo '[]' > "$HISTORY"
  jq --arg t "$title" --argjson max "$MAX_HISTORY" '
    . + [$t] | if length > $max then .[(length - $max):] else . end
  ' "$HISTORY" > "$HISTORY.tmp" && mv "$HISTORY.tmp" "$HISTORY"

  # Output spinner update to stdout (Claude Code reads hook stdout)
  local remaining
  remaining=$(jq 'length' "$POOL")
  local display="${title} [${remaining}]"
  jq -n --arg v "$display" '{"spinnerVerbs":{"mode":"replace","verbs":[$v]}}'
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
