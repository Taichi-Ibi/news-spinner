#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINNER_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"   # PROJECT/.claude/
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

usage() {
  cat <<'EOF'
Usage: fetch.sh [--since YYYY-MM-DD] <keyword> [keyword2 ...]
       fetch.sh clear
       fetch.sh help

Options:
  --since YYYY-MM-DD  Only include articles published on or after this date

Examples:
  fetch.sh Claude ChatGPT Gemini
  fetch.sh --since 2026-03-01 高市
  fetch.sh clear
EOF
}

# URL-encode a string — processes raw bytes to handle multi-byte UTF-8 correctly
urlencode() {
  printf '%s' "$1" | od -An -tx1 | tr -d ' \n' | fold -w2 | while IFS= read -r hex || [ -n "$hex" ]; do
    chr=$(printf "\\x$hex")
    case "$chr" in
      [a-zA-Z0-9.~_-]) printf '%s' "$chr" ;;
      ' ') printf '+' ;;
      *) printf '%%%s' "${hex^^}" ;;
    esac
  done
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

# Convert RSS pubDate ("Sat, 01 Mar 2026 10:00:00 GMT") to YYYY-MM-DD
pubdate_to_ymd() {
  local pubdate="$1"
  [ -z "$pubdate" ] && echo "" && return
  local day month_name year month
  day=$(echo "$pubdate" | awk '{print $2}')
  month_name=$(echo "$pubdate" | awk '{print $3}')
  year=$(echo "$pubdate" | awk '{print $4}')
  case "$month_name" in
    Jan) month="01" ;; Feb) month="02" ;; Mar) month="03" ;;
    Apr) month="04" ;; May) month="05" ;; Jun) month="06" ;;
    Jul) month="07" ;; Aug) month="08" ;; Sep) month="09" ;;
    Oct) month="10" ;; Nov) month="11" ;; Dec) month="12" ;;
    *) echo "" ; return ;;
  esac
  printf '%s-%s-%02d\n' "$year" "$month" "$((10#$day))"
}

# Extract pubDate<TAB>title pairs from RSS XML (compact/single-line items)
extract_items() {
  local xml="$1"
  echo "$xml" | sed -E 's/<\/item>/&\n/g' | grep -E '^<item>' | while IFS= read -r item; do
    local title pubdate
    title=$(echo "$item" | tr '<' '\n' | grep '^title>' | head -1 \
      | sed 's/^title>//' | sed 's/<!\[CDATA\[//;s/\]\]>//')
    pubdate=$(echo "$item" | grep -oE '<pubDate>[^<]*</pubDate>' | head -1 \
      | sed 's/<pubDate>//;s/<\/pubDate>//')
    [ -n "$title" ] && printf '%s\t%s\n' "$pubdate" "$title"
  done
}

do_fetch() {
  local start_date="$1"
  shift
  local keywords=("$@")

  if [ "${#keywords[@]}" -eq 0 ]; then
    echo "No keywords specified. Usage: fetch.sh <keyword> [keyword2 ...]" >&2
    exit 1
  fi

  local pool_json history_json
  pool_json=$(cat "$POOL")
  history_json=$(cat "$HISTORY")

  local added=0
  local pool_size
  pool_size=$(echo "$pool_json" | jq 'length')
  local pool_full=false

  for keyword in "${keywords[@]}"; do
    [ "$pool_full" = true ] && break

    local url xml
    url=$(build_url "$keyword")

    echo "Fetching: $keyword ..."

    xml=$(curl -sL --max-time 10 "$url" 2>/dev/null) || {
      echo "  Warning: Failed to fetch ($keyword)" >&2
      continue
    }

    local new_titles=()

    while IFS=$'\t' read -r pub_raw raw_title; do
      [ -z "$raw_title" ] && continue

      # Trim whitespace
      raw_title="${raw_title#"${raw_title%%[![:space:]]*}"}"
      raw_title="${raw_title%"${raw_title##*[![:space:]]}"}"
      [ -z "$raw_title" ] && continue

      # Filter by start_date
      if [ -n "$start_date" ]; then
        local article_ymd
        article_ymd=$(pubdate_to_ymd "$pub_raw")
        if [ -n "$article_ymd" ] && [[ "$article_ymd" < "$start_date" ]]; then
          continue
        fi
      fi

      local title="$raw_title"

      # Dedup check
      if echo "$pool_json" | jq -e --arg t "$title" 'index($t) != null' > /dev/null 2>&1; then
        continue
      fi
      if echo "$history_json" | jq -e --arg t "$title" 'index($t) != null' > /dev/null 2>&1; then
        continue
      fi

      new_titles+=("$title")
      pool_json=$(echo "$pool_json" | jq --arg t "$title" '. + [$t]')
      pool_size=$((pool_size + 1))
      added=$((added + 1))

      if [ "$pool_size" -ge "$MAX_POOL_SIZE" ]; then
        echo "  Pool is full ($MAX_POOL_SIZE). Stopping."
        pool_full=true
        break
      fi
    done < <(extract_items "$xml")

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

# Parse --since option
START_DATE=""
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      START_DATE="${2:-}"
      [[ "$START_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || {
        echo "Error: --since requires a date in YYYY-MM-DD format" >&2; exit 1
      }
      shift 2
      ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done
set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

case "${1:-}" in
  clear)
    echo '[]' > "$POOL"
    echo "Pool cleared."
    ;;
  -h|--help|help)
    usage
    ;;
  "")
    usage
    exit 1
    ;;
  *)
    if command -v flock > /dev/null 2>&1; then
      exec 9>"$LOCK"
      flock -w 10 9 || { echo "Error: Could not acquire lock." >&2; exit 1; }
      do_fetch "$START_DATE" "$@"
      exec 9>&-
    else
      do_fetch "$START_DATE" "$@"
    fi
    bash "$SCRIPT_DIR/rotate.sh" 2>/dev/null || true
    ;;
esac
