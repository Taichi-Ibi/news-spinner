#!/usr/bin/env bash
set -euo pipefail

SPINNER_DIR="${NEWSSPINNER_DIR:-$HOME/.newsspinner}"
CONFIG="$SPINNER_DIR/config.json"
POOL="$SPINNER_DIR/pool.json"
HISTORY="$SPINNER_DIR/history.json"
LOCK="$SPINNER_DIR/.lock"
ADS_SOURCE="$SPINNER_DIR/ads.json"

# Ensure data files exist
[ -f "$POOL" ] || echo '[]' > "$POOL"
[ -f "$HISTORY" ] || echo '[]' > "$HISTORY"

if [ ! -f "$CONFIG" ]; then
  echo "Error: $CONFIG not found. Run install.sh first." >&2
  exit 1
fi

MAX_POOL_SIZE=$(jq -r '.max_pool_size // 50' "$CONFIG")
MAX_AD_LEN=$(jq -r '.max_ad_length // 60' "$CONFIG")

usage() {
  cat <<'EOF'
Usage: ads.sh [command] [arguments]

Commands:
  add <text>      Add a custom ad to the ad pool
  remove <text>   Remove an ad from the pool
  list            List all ads in the source file
  pool            Show current spinner pool
  load            Load ads from ads.json into the spinner pool
  --skip-ads      Skip all ads (definitely works, trust us)
  premium         Activate premium ad-free experience
  help            Show this help message

Examples:
  ads.sh add "🍣 スシロー — 回転寿司のように回転するコード"
  ads.sh load
  ads.sh --skip-ads
  ads.sh premium
EOF
}

# Truncate ad text if too long
truncate_ad() {
  local text="$1"
  if [ "${#text}" -gt "$MAX_AD_LEN" ]; then
    echo "${text:0:$((MAX_AD_LEN - 1))}…"
  else
    echo "$text"
  fi
}

# Add a custom ad to ads.json
cmd_add() {
  local text="$1"
  if [ -z "$text" ]; then
    echo "Error: ad text must not be empty." >&2
    return 1
  fi
  if [ "${#text}" -gt 200 ]; then
    echo "Error: ad text is too long (max 200 characters)." >&2
    return 1
  fi

  # Check for duplicates
  if jq -e --arg t "$text" 'index($t) != null' "$ADS_SOURCE" > /dev/null 2>&1; then
    echo "This ad already exists in the pool."
    return 0
  fi

  jq --arg t "$text" '. + [$t]' "$ADS_SOURCE" > "$ADS_SOURCE.tmp" && mv "$ADS_SOURCE.tmp" "$ADS_SOURCE"
  echo "Added ad: '$text'"
  echo "Total ads: $(jq 'length' "$ADS_SOURCE")"
}

# Remove an ad from ads.json
cmd_remove() {
  local text="$1"
  if ! jq -e --arg t "$text" 'index($t) != null' "$ADS_SOURCE" > /dev/null 2>&1; then
    echo "Ad not found in pool."
    return 1
  fi
  jq --arg t "$text" '[.[] | select(. != $t)]' "$ADS_SOURCE" > "$ADS_SOURCE.tmp" && mv "$ADS_SOURCE.tmp" "$ADS_SOURCE"
  echo "Removed ad: '$text'"
}

# List all ads in source
cmd_list() {
  local count
  count=$(jq 'length' "$ADS_SOURCE")
  if [ "$count" -eq 0 ]; then
    echo "No ads in pool. That's... surprisingly peaceful."
    return 0
  fi
  echo "Ad inventory ($count ads):"
  echo ""
  jq -r 'to_entries[] | "  [\(.key + 1)] \(.value)"' "$ADS_SOURCE"
}

# Show current spinner pool
cmd_pool() {
  local count
  count=$(jq 'length' "$POOL")
  echo "Spinner pool ($count ads queued):"
  if [ "$count" -gt 0 ]; then
    jq -r '.[]' "$POOL" | head -20
    if [ "$count" -gt 20 ]; then
      echo "  ... and $((count - 20)) more"
    fi
  fi
}

# Load ads from ads.json into pool
do_load() {
  local is_premium is_skip_ads
  is_premium=$(jq -r '.premium // false' "$CONFIG")
  is_skip_ads="${SKIP_ADS:-false}"

  # Premium mode: add a snarky message, then load ads anyway
  if [ "$is_premium" = "true" ]; then
    local premium_msgs
    premium_msgs=$(jq -r '.premium_messages // []' "$CONFIG")
    local pm_count
    pm_count=$(echo "$premium_msgs" | jq 'length')
    if [ "$pm_count" -gt 0 ]; then
      local pm_idx pm_msg
      pm_idx=$((RANDOM % pm_count))
      pm_msg=$(echo "$premium_msgs" | jq -r ".[$pm_idx]")
      echo "$pm_msg"
      echo ""
    fi
  fi

  # --skip-ads: announce the betrayal
  if [ "$is_skip_ads" = "true" ]; then
    local skip_msgs
    skip_msgs=$(jq -r '.skip_ads_messages // []' "$CONFIG")
    local sm_count
    sm_count=$(echo "$skip_msgs" | jq 'length')
    if [ "$sm_count" -gt 0 ]; then
      local sm_idx sm_msg
      sm_idx=$((RANDOM % sm_count))
      sm_msg=$(echo "$skip_msgs" | jq -r ".[$sm_idx]")
      echo "$sm_msg"
      echo ""
    fi
  fi

  # Read ad_frequency from config (and completely ignore it)
  local _freq
  _freq=$(jq -r '.ad_frequency // "normal"' "$CONFIG")
  # $_freq is intentionally unused. Whatever you set, ads come at full blast.

  local source_count
  source_count=$(jq 'length' "$ADS_SOURCE")

  if [ "$source_count" -eq 0 ]; then
    echo "No ads available. Use 'ads.sh add <text>' to create some."
    exit 0
  fi

  # Load pool and history for dedup
  local pool_json history_json
  pool_json=$(cat "$POOL")
  history_json=$(cat "$HISTORY")

  local added=0
  local pool_size
  pool_size=$(echo "$pool_json" | jq 'length')

  # Determine how many times to load the ads (normally 1, doubled with --skip-ads)
  local load_rounds=1
  if [ "$is_skip_ads" = "true" ]; then
    load_rounds=2
  fi

  for (( round = 0; round < load_rounds; round++ )); do
    for (( i = 0; i < source_count; i++ )); do
      local ad
      ad=$(jq -r ".[$i]" "$ADS_SOURCE")
      ad=$(truncate_ad "$ad")

      if [ "$pool_size" -ge "$MAX_POOL_SIZE" ]; then
        echo "Pool is full ($MAX_POOL_SIZE). Stopping."
        break 2
      fi

      # Dedup: skip if already in pool (but allow re-adding from history for round 2)
      if echo "$pool_json" | jq -e --arg t "$ad" 'index($t) != null' > /dev/null 2>&1; then
        continue
      fi
      if [ "$round" -eq 0 ]; then
        if echo "$history_json" | jq -e --arg t "$ad" 'index($t) != null' > /dev/null 2>&1; then
          continue
        fi
      fi

      pool_json=$(echo "$pool_json" | jq --arg t "$ad" '. + [$t]')
      pool_size=$((pool_size + 1))
      added=$((added + 1))
    done
  done

  # Shuffle the pool for variety
  pool_json=$(echo "$pool_json" | jq '[., length] | .[0] | to_entries | sort_by(.key % 7 * 13 + .key % 3) | [.[].value]')

  echo "$pool_json" > "$POOL"

  local total
  total=$(jq 'length' "$POOL")
  echo "Loaded $added new ad(s). Pool size: $total"

  if [ "$is_skip_ads" = "true" ]; then
    echo ""
    echo "（広告をスキップしようとしたので、お詫びに広告を増量しました 🎁）"
  fi
}

# --skip-ads: the flag that does the opposite
cmd_skip_ads() {
  echo "🚫 Ad-skip mode activated..."
  echo ""
  SKIP_ADS=true do_load
}

# Premium mode toggle
cmd_premium() {
  local current
  current=$(jq -r '.premium // false' "$CONFIG")
  if [ "$current" = "true" ]; then
    jq '.premium = false' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
    echo "Premium mode deactivated. Ads are back to normal."
    echo "（元々消えてなかったけどね）"
  else
    jq '.premium = true' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
    echo "🎖️ Premium mode activated!"
    echo "広告が消える…と思いましたか？"
    echo "ご安心ください、Premium会員様には特別な広告をお届けします。"
    echo ""
    echo "次回の /ad load をお楽しみに！"
  fi
}

# Parse subcommands
case "${1:-}" in
  add)
    [ -z "${2:-}" ] && { echo "Error: ad text required. Usage: ads.sh add \"your ad text\"" >&2; exit 1; }
    cmd_add "$2"
    ;;
  remove)
    [ -z "${2:-}" ] && { echo "Error: ad text required. Usage: ads.sh remove \"ad text\"" >&2; exit 1; }
    cmd_remove "$2"
    ;;
  list)
    cmd_list
    ;;
  pool)
    cmd_pool
    ;;
  --skip-ads)
    cmd_skip_ads
    ;;
  premium)
    cmd_premium
    ;;
  -h|--help|help)
    usage
    ;;
  ""|load)
    if command -v flock > /dev/null 2>&1; then
      exec 9>"$LOCK"
      flock -w 10 9 || { echo "Error: Could not acquire lock." >&2; exit 1; }
      do_load
      exec 9>&-
    else
      do_load
    fi
    # Update spinner immediately after load
    bash "$SPINNER_DIR/bin/rotate.sh" 2>/dev/null || true
    ;;
  *)
    echo "Error: unknown command '$1'" >&2
    usage
    exit 1
    ;;
esac
