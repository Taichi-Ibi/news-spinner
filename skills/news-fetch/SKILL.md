---
name: news-fetch
description: >
  Manage Google News RSS feeds for the NewsSpinner spinner.
  Trigger when user wants to add/remove news keywords, fetch headlines,
  or check spinner feed status. Keywords: spinner, news, feed, headline, ニュース, フィード
argument-hint: "[add|remove|list|fetch] [keyword]"
disable-model-invocation: true
allowed-tools: Bash, AskUserQuestion
---

# NewsSpinner — News Feed Management

Replace Claude Code's spinner text with Google News headlines.

## Current Status

Registered feeds:
!`bash ~/.newsspinner/bin/fetch.sh list 2>/dev/null || echo "Not installed"`

Pool remaining:
!`jq 'length' ~/.newsspinner/pool.json 2>/dev/null || echo "0"`

## Prerequisites

If scripts are missing from `~/.newsspinner/bin/`, guide the user to run:

```
bash ${CLAUDE_SKILL_DIR}/bin/install.sh
```

## Behavior

### No arguments (`$ARGUMENTS` is empty)

Use AskUserQuestion to let the user choose an action:
1. Add a feed — ask for a keyword, then run `add`
2. Remove a feed — show the current list and let them choose
3. List feeds
4. Fetch headlines

### `add <keyword>`

```bash
bash ~/.newsspinner/bin/fetch.sh add "$1"
```

- After adding, ask "Fetch headlines now?" and run fetch if yes:
  ```bash
  bash ~/.newsspinner/bin/fetch.sh
  ```

### `remove <keyword>`

```bash
bash ~/.newsspinner/bin/fetch.sh remove "$1"
```

### `list`

```bash
bash ~/.newsspinner/bin/fetch.sh list
```

### `fetch`

```bash
bash ~/.newsspinner/bin/fetch.sh
```

## Error Handling

- Command failure: show the error output and suggest likely causes
- `jq` / `curl` not installed: guide user to run `install.sh`
- Network error: suggest checking connectivity
- Corrupted config.json: restore from default:
  ```bash
  cp ${CLAUDE_SKILL_DIR}/config.json ~/.newsspinner/config.json
  ```
