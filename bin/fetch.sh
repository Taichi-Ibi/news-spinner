#!/usr/bin/env bash
set -euo pipefail

SPINNER_DIR="${NEWSSPINNER_DIR:-$HOME/.newsspinner}"
CONFIG="$SPINNER_DIR/config.json"
POOL="$SPINNER_DIR/pool.json"
HISTORY="$SPINNER_DIR/history.json"
LOCK="$SPINNER_DIR/.lock"

# Ensure files exist
[ -f "$POOL" ] || echo '[]' > "$POOL"
[ -f "$HISTORY" ] || echo '[]' > "$HISTORY"

if [ ! -f "$CONFIG" ]; then
  echo "Error: $CONFIG not found. Run install.sh first." >&2
  exit 1
fi

MAX_POOL_SIZE=$(jq -r '.max_pool_size // 50' "$CONFIG")
MAX_TITLE_LEN=$(jq -r '.max_title_length // 40' "$CONFIG")

usage() {
  echo "Usage: fetch.sh [options]"
  echo ""
  echo "Options:"
  echo "  add <keyword>        Add a Google News feed for the keyword"
  echo "  remove <keyword>     Remove a feed by keyword"
  echo "  list                 List registered feeds"
  echo "  (no args)            Fetch all registered feeds"
  echo ""
  echo "Examples:"
  echo "  fetch.sh add AI"
  echo "  fetch.sh add \"Claude Code\""
  echo "  fetch.sh remove AI"
  echo "  fetch.sh list"
  echo "  fetch.sh              # fetch all feeds"
}

# Build Google News RSS URL from keyword
build_url() {
  local keyword="$1"
  local base_url hl gl ceid
  base_url=$(jq -r '.base_url // "https://news.google.com/rss/search"' "$CONFIG")
  hl=$(jq -r '.default_params.hl // "ja"' "$CONFIG")
  gl=$(jq -r '.default_params.gl // "JP"' "$CONFIG")
  ceid=$(jq -r '.default_params.ceid // "JP:ja"' "$CONFIG")
  # URL-encode the keyword (basic: spaces → +)
  local encoded
  encoded=$(printf '%s' "$keyword" | sed 's/ /+/g')
  echo "${base_url}?q=${encoded}&hl=${hl}&gl=${gl}&ceid=${ceid}"
}

# Subcommand: add a feed
cmd_add() {
  local keyword="$1"
  # Check if already exists
  if jq -e --arg k "$keyword" '.feeds[] | select(.keyword == $k)' "$CONFIG" > /dev/null 2>&1; then
    echo "Feed for '$keyword' already exists."
    return 0
  fi
  local url
  url=$(build_url "$keyword")
  jq --arg k "$keyword" --arg u "$url" \
    '.feeds += [{"keyword": $k, "url": $u}]' \
    "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
  echo "Added feed: '$keyword' → $url"
}

# Subcommand: remove a feed
cmd_remove() {
  local keyword="$1"
  if ! jq -e --arg k "$keyword" '.feeds[] | select(.keyword == $k)' "$CONFIG" > /dev/null 2>&1; then
    echo "Feed for '$keyword' not found."
    return 1
  fi
  jq --arg k "$keyword" '.feeds = [.feeds[] | select(.keyword != $k)]' \
    "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
  echo "Removed feed: '$keyword'"
}

# Subcommand: list feeds
cmd_list() {
  local count
  count=$(jq '.feeds | length' "$CONFIG")
  if [ "$count" -eq 0 ]; then
    echo "No feeds registered. Use 'fetch.sh add <keyword>' to add one."
    return 0
  fi
  echo "Registered feeds ($count):"
  jq -r '.feeds[] | "  [\(.keyword)] → \(.url)"' "$CONFIG"
}

# Truncate title if needed
truncate_title() {
  local title="$1"
  if [ "${#title}" -gt "$MAX_TITLE_LEN" ]; then
    echo "${title:0:$((MAX_TITLE_LEN - 1))}…"
  else
    echo "$title"
  fi
}

# Extract titles from RSS/Atom XML
extract_titles() {
  local xml="$1"
  grep -oP '<title[^>]*>\s*(?:<!\[CDATA\[)?\K[^<\]]+' <<< "$xml" | tail -n +2
}

do_fetch() {
  local feed_count
  feed_count=$(jq -r '.feeds | length' "$CONFIG")

  if [ "$feed_count" -eq 0 ]; then
    echo "No feeds registered. Use 'fetch.sh add <keyword>' to add one."
    exit 0
  fi

  local added=0

  for ((i = 0; i < feed_count; i++)); do
    local url keyword xml
    url=$(jq -r ".feeds[$i].url" "$CONFIG")
    keyword=$(jq -r ".feeds[$i].keyword" "$CONFIG")

    echo "Fetching: $keyword ..."

    # Fetch RSS feed
    xml=$(curl -sL --max-time 10 "$url" 2>/dev/null) || {
      echo "  Warning: Failed to fetch ($url)" >&2
      continue
    }

    # Extract and process titles
    while IFS= read -r raw_title; do
      [ -z "$raw_title" ] && continue

      # Trim whitespace
      raw_title=$(echo "$raw_title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      [ -z "$raw_title" ] && continue

      local title
      title=$(truncate_title "$raw_title")

      # Check current pool size
      local pool_size
      pool_size=$(jq 'length' "$POOL")
      if [ "$pool_size" -ge "$MAX_POOL_SIZE" ]; then
        echo "Pool is full ($MAX_POOL_SIZE). Stopping." >&2
        break 2
      fi

      # Check for duplicates in pool and history
      if jq -e --arg t "$title" 'index($t) != null' "$POOL" > /dev/null 2>&1; then
        continue
      fi
      if jq -e --arg t "$title" 'index($t) != null' "$HISTORY" > /dev/null 2>&1; then
        continue
      fi

      # Add to pool
      jq --arg t "$title" '. + [$t]' "$POOL" > "$POOL.tmp" && mv "$POOL.tmp" "$POOL"
      added=$((added + 1))
    done < <(extract_titles "$xml")
  done

  local total
  total=$(jq 'length' "$POOL")
  echo "Added $added new titles. Pool size: $total"
}

# Parse subcommands
case "${1:-}" in
  add)
    [ -z "${2:-}" ] && { echo "Error: keyword required. Usage: fetch.sh add <keyword>" >&2; exit 1; }
    cmd_add "$2"
    ;;
  remove)
    [ -z "${2:-}" ] && { echo "Error: keyword required. Usage: fetch.sh remove <keyword>" >&2; exit 1; }
    cmd_remove "$2"
    ;;
  list)
    cmd_list
    ;;
  -h|--help|help)
    usage
    ;;
  "")
    # No args: fetch all feeds
    if command -v flock > /dev/null 2>&1; then
      exec 9>"$LOCK"
      flock -w 10 9 || { echo "Error: Could not acquire lock" >&2; exit 1; }
      do_fetch
      exec 9>&-
    else
      do_fetch
    fi
    # Run rotate once to update spinner immediately
    bash "$SPINNER_DIR/bin/rotate.sh" 2>/dev/null || true
    ;;
  *)
    echo "Unknown command: $1" >&2
    usage
    exit 1
    ;;
esac
