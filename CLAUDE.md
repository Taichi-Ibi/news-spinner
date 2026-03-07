# CLAUDE.md — NewsSpinner Project Guidelines

This file provides project-specific guidance for developing NewsSpinner. Claude Code will read this automatically at session start.

## Project Overview

NewsSpinner is a Claude Code integration that replaces spinner verbs with live news headlines fetched from Google News RSS.

The project is primarily **Bash-based** with JSON configuration files and a skill system for CLI commands.

## Architecture

- **Hook**: `rotate.sh` is registered as the `PostToolUse` hook; picks a random headline from the pool on every tool call
- **Runtime data**: Stored in `.claude/skills/news-spinner/runtime/` (gitignored); `state.json` holds feature flags
- **Config template**: `templates/config.json` and `templates/state.json` are git-tracked defaults; copied to `runtime/` on install
- **Installation**: `install.sh` / `uninstall.sh` manage hook registration and runtime setup

## Workflow Rules

### 1. Before Making Changes
- Always read the relevant shell scripts first (especially `fetch.sh`, `rotate.sh`)
- Verify JSON structure of config files before modifying them

### 2. Shell Script Guidelines
- Use `bash` v4+ features safely; test with `bash --version` expectations
- Prefer `jq` for JSON parsing over manual string manipulation
- Include error checking with `set -e` where appropriate
- Avoid hardcoded paths; use relative paths when possible
- Test scripts in isolation before integrating into the install flow

### 3. JSON Configuration
- Always validate JSON syntax after edits (not just assumed)
- Keys like `max_pool_size`, `max_title_length` have functional impact — document changes clearly
- The `empty_messages` array is user-facing; keep entries concise and witty

### 4. Installation Safety
- **Never modify** the installation order without testing
- Uninstall should cleanly remove: hook references, runtime files, skill directory
- Document any new runtime files that install.sh creates

### 5. Skill Commands
- `/news-spinner <keyword>…`, `--since DATE`, `clear`, `weave on/off`, `uninstall`
- Skill behavior is defined in `.claude/skills/news-spinner/SKILL.md`; update it when command behavior changes

### 6. Testing & Verification
- After changes to fetch.sh: manually run it and verify `runtime/pool.json` structure
- After changes to rotate.sh: verify spinner text updates on at least one tool call
- Check that the hook stays registered in `.claude/settings.json` after installation

## Common Patterns

### Adding a new configuration option
1. Add the key to `templates/config.json`
2. Update `fetch.sh` or `rotate.sh` to read and use it
3. Update README.md with documentation of the new option
4. Document default behavior when the key is missing

### Modifying Google News fetch behavior
- The `base_url`, `default_params.hl`, `.gl`, and `.ceid` control the news source
- Changing these affects what headlines appear; test with different locales
- `max_pool_size` and `max_title_length` are truncation settings; verify they don't break long titles

## Code Quality

### Do
- Keep shell scripts focused on one responsibility (fetch, rotate)
- Use meaningful variable names in Bash (not `x`, `tmp`, etc.)
- Test locale settings (ja vs en) before merging
- Ensure JSON is pretty-printed for readability

### Don't
- Hardcode file paths; use `$SKILL_DIR` / `$RUNTIME_DIR` variables
- Assume jq is available without checking; it's a required dependency

## File Locations

- Shell scripts: `.claude/skills/news-spinner/bin/*.sh`
- Skill metadata: `.claude/skills/news-spinner/SKILL.md`
- Config templates (git-tracked): `.claude/skills/news-spinner/templates/config.json`
- Runtime config (user-local): `.claude/skills/news-spinner/runtime/config.json` (copied from templates on install)
- Feature flags: `.claude/skills/news-spinner/runtime/state.json` (`weave_enabled`)
- Spinner pool: `.claude/skills/news-spinner/runtime/pool.json`
- History: `.claude/skills/news-spinner/runtime/history.json`
- Weave tracking script: `.claude/skills/news-spinner/bin/weave_track.py`

## When in Doubt

- Check how the install script sets up these files
- Verify `.claude/settings.json` still has the correct hook registration
- Ensure uninstall cleanly removes what install added
