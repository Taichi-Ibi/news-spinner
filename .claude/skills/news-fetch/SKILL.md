---
name: news-fetch
description: >
  Fetch Google News headlines into the NewsSpinner spinner pool.
  Trigger when user wants to fetch news headlines, search keywords, or manage spinner content.
  Keywords: spinner, news, fetch, headline, ニュース, フィード
argument-hint: "[--since YYYY-MM-DD] <keyword> [keyword2 ...]"
disable-model-invocation: true
allowed-tools: Bash, AskUserQuestion
---

# NewsSpinner — News Fetch

Replace Claude Code's spinner text with Google News headlines.

## Current Status

Pool remaining:
!`SPINNER_DIR="$(cd "${CLAUDE_SKILL_DIR}/../../.." && pwd)" && jq 'length' "$SPINNER_DIR/pool.json" 2>/dev/null || echo "0"`

## Prerequisites

If not yet installed, guide the user to run:

```
bash "${CLAUDE_SKILL_DIR}/bin/install.sh"
```

## Behavior

### No arguments (`$ARGUMENTS` is empty)

Use AskUserQuestion to ask the user which keyword(s) to fetch.

### `<keyword> [keyword2 ...]` or `[--since YYYY-MM-DD] <keyword> ...`

```bash
bash "${CLAUDE_SKILL_DIR}/bin/fetch.sh" $ARGUMENTS
```

Parse keywords and optional `--since` from `$ARGUMENTS` and pass them directly.

Examples:
- `Claude ChatGPT Gemini` → fetch all three
- `--since 2026-03-01 高市` → fetch 高市 news from March 1st onward
- `高市 この1週間` → interpret "この1週間" as `--since <7 days ago>` and run:
  ```bash
  bash "${CLAUDE_SKILL_DIR}/bin/fetch.sh" --since <YYYY-MM-DD> 高市
  ```

### `clear`

```bash
bash "${CLAUDE_SKILL_DIR}/bin/fetch.sh" clear
```

## Error Handling

- Command failure: show the error output and suggest likely causes
- `jq` / `curl` not installed: guide user to run `install.sh`
- Network error: suggest checking connectivity
- Corrupted config.json: restore from default:
  ```bash
  SPINNER_DIR="$(cd "${CLAUDE_SKILL_DIR}/../../.." && pwd)"
  cp "${CLAUDE_SKILL_DIR}/config.json" "$SPINNER_DIR/config.json"
  ```
