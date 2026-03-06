#!/usr/bin/env bash
set -euo pipefail

SPINNER_DIR="${NEWSSPINNER_DIR:-$HOME/.newsspinner}"
CONFIG="$SPINNER_DIR/config.json"
POOL="$SPINNER_DIR/pool.json"
HISTORY="$SPINNER_DIR/history.json"
LOCK="$SPINNER_DIR/.lock"

# Ensure data files exist
[ -f "$POOL" ] || echo '[]' > "$POOL"
[ -f "$HISTORY" ] || echo '[]' > "$HISTORY"

if [ ! -f "$CONFIG" ]; then
  echo "Error: $CONFIG not found. Run install.sh first." >&2
  exit 1
fi

MAX_POOL_SIZE=$(jq -r '.max_pool_size // 50' "$CONFIG")
MAX_TITLE_LEN=$(jq -r '.max_title_length // 40' "$CONFIG")

usage() {
  cat <<'EOF'
Usage: fetch.sh [command] [arguments]

Commands:
  add <keyword>     Add a Google News feed for the keyword
  remove <keyword>  Remove a feed by keyword
  list              List registered feeds
  help              Show this help message
  (no command)      Fetch headlines from all registered feeds

Examples:
  fetch.sh add AI
  fetch.sh add "Claude Code"
  fetch.sh remove AI
  fetch.sh list
  fetch.sh              # fetch all feeds
EOF
}

# URL-encode a string (POSIX-portable, no perl/python dependency)
urlencode() {
  local string="$1" i c
  local length=${#string}
  for (( i = 0; i < length; i++ )); do
    c="${string:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
      ' ')              printf '+' ;;
      *)                printf '%%%02X' "'$c" ;;
    esac
  done
}

# Validate keyword: reject empty, excessively long, or control-char-laden input
validate_keyword() {
  local keyword="$1"
  if [ -z "$keyword" ]; then
    echo "Error: keyword must not be empty." >&2
    return 1
  fi
  if [ "${#keyword}" -gt 100 ]; then
    echo "Error: keyword is too long (max 100 characters)." >&2
    return 1
  fi
  # Reject control characters (except space)
  if [[ "$keyword" =~ [[:cntrl:]] ]]; then
    echo "Error: keyword contains invalid characters." >&2
    return 1
  fi
}

# Build Google News RSS URL from keyword
build_url() {
  local keyword="$1"
  local base_url hl gl ceid encoded
  base_url=$(jq -r '.base_url // "https://news.google.com/rss/search"' "$CONFIG")
  hl=$(jq -r '.default_params.hl // "ja"' "$CONFIG")
  gl=$(jq -r '.default_params.gl // "JP"' "$CONFIG")
  ceid=$(jq -r '.default_params.ceid // "JP:ja"' "$CONFIG")
  encoded=$(urlencode "$keyword")
  echo "${base_url}?q=${encoded}&hl=${hl}&gl=${gl}&ceid=${ceid}"
}

# Subcommand: add a feed
cmd_add() {
  local keyword="$1"
  validate_keyword "$keyword"

  if jq -e --arg k "$keyword" '.feeds[] | select(.keyword == $k)' "$CONFIG" > /dev/null 2>&1; then
    echo "Feed for '$keyword' already exists."
    return 0
  fi

  local url
  url=$(build_url "$keyword")
  jq --arg k "$keyword" --arg u "$url" \
    '.feeds += [{"keyword": $k, "url": $u}]' \
    "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
  echo "Added feed: '$keyword'"
}

# Subcommand: remove a feed
cmd_remove() {
  local keyword="$1"
  validate_keyword "$keyword"

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
  jq -r '.feeds[] | "  [\(.keyword)] \(.url)"' "$CONFIG"
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

# Extract titles from RSS XML (portable — no grep -P)
extract_titles() {
  local xml="$1"
  # Match <title>...</title> or <title><![CDATA[...]]></title>
  # Skip the first <title> which is the feed title, not an article
  echo "$xml" \
    | sed -n 's/.*<title[^>]*>\s*\(<!\[CDATA\[\)\?\(.*\)\(\]\]>\)\?\s*<\/title>.*/\2/p' \
    | tail -n +2
}

do_fetch() {
  local feed_count
  feed_count=$(jq -r '.feeds | length' "$CONFIG")

  if [ "$feed_count" -eq 0 ]; then
    echo "No feeds registered. Use 'fetch.sh add <keyword>' to add one."
    exit 0
  fi

  # Load pool and history into shell variables for fast dedup
  local pool_json history_json
  pool_json=$(cat "$POOL")
  history_json=$(cat "$HISTORY")

  local added=0
  local pool_size
  pool_size=$(echo "$pool_json" | jq 'length')

  for (( i = 0; i < feed_count; i++ )); do
    local url keyword xml
    url=$(jq -r ".feeds[$i].url" "$CONFIG")
    keyword=$(jq -r ".feeds[$i].keyword" "$CONFIG")

    echo "Fetching: $keyword ..."

    xml=$(curl -sL --max-time 10 "$url" 2>/dev/null) || {
      echo "  Warning: Failed to fetch ($keyword)" >&2
      continue
    }

    local new_titles=()

    while IFS= read -r raw_title; do
      [ -z "$raw_title" ] && continue

      # Trim whitespace
      raw_title="${raw_title#"${raw_title%%[![:space:]]*}"}"
      raw_title="${raw_title%"${raw_title##*[![:space:]]}"}"
      [ -z "$raw_title" ] && continue

      local title
      title=$(truncate_title "$raw_title")

      if [ "$pool_size" -ge "$MAX_POOL_SIZE" ]; then
        echo "  Pool is full ($MAX_POOL_SIZE). Stopping."
        break 2
      fi

      # Fast dedup check via jq on cached JSON
      if echo "$pool_json" | jq -e --arg t "$title" 'index($t) != null' > /dev/null 2>&1; then
        continue
      fi
      if echo "$history_json" | jq -e --arg t "$title" 'index($t) != null' > /dev/null 2>&1; then
        continue
      fi

      new_titles+=("$title")
      # Update in-memory pool for subsequent dedup
      pool_json=$(echo "$pool_json" | jq --arg t "$title" '. + [$t]')
      pool_size=$((pool_size + 1))
      added=$((added + 1))
    done < <(extract_titles "$xml")

    # Batch-write new titles for this feed
    if [ "${#new_titles[@]}" -gt 0 ]; then
      local batch
      batch=$(printf '%s\n' "${new_titles[@]}" | jq -R . | jq -s .)
      jq --argjson new "$batch" '. + $new' "$POOL" > "$POOL.tmp" && mv "$POOL.tmp" "$POOL"
    fi
  done

  local total
  total=$(jq 'length' "$POOL")
  echo "Added $added new headline(s). Pool size: $total"
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
    if command -v flock > /dev/null 2>&1; then
      exec 9>"$LOCK"
      flock -w 10 9 || { echo "Error: Could not acquire lock." >&2; exit 1; }
      do_fetch
      exec 9>&-
    else
      do_fetch
    fi
    # Update spinner immediately after fetch
    bash "$SPINNER_DIR/bin/rotate.sh" 2>/dev/null || true
    ;;
  *)
    echo "Error: unknown command '$1'" >&2
    usage
    exit 1
    ;;
esac
