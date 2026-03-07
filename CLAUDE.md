# CLAUDE.md — NewsSpinner Project Guidelines

This file provides project-specific guidance for developing NewsSpinner. Claude Code will read this automatically at session start.

## Project Overview

NewsSpinner is a Claude Code integration that replaces spinner verbs with live news headlines or fake sponsor ads. It consists of two modes:
- **News mode**: Fetches headlines from Google News RSS feed
- **Joke Ads mode**: Displays hardcoded fake sponsor advertisements

The project is primarily **Bash-based** with JSON configuration files and a skill system for CLI commands.

## Architecture

- **Shared components**: `rotate.sh` is used by both modes as the `PostToolUse` hook
- **Mode separation**: News and Joke Ads are installed independently under `.claude/skills/`
- **Runtime data**: All state is stored in `.claude/` directory (config, pool, history, ads)
- **Installation**: Both have their own `install.sh` and `uninstall.sh` scripts

## Workflow Rules

### 1. Before Making Changes
- Always read the relevant shell scripts first (especially `fetch.sh`, `ads.sh`, `rotate.sh`)
- Verify JSON structure of config files before modifying them
- Check both mode implementations if changes affect shared code (like `rotate.sh`)

### 2. Shell Script Guidelines
- Use `bash` v4+ features safely; test with `bash --version` expectations
- Prefer `jq` for JSON parsing over manual string manipulation
- Include error checking with `set -e` where appropriate
- Avoid hardcoded paths; use relative paths when possible
- Test scripts in isolation before integrating into the install flow

### 3. JSON Configuration
- Always validate JSON syntax after edits (not just assumed)
- Keys like `max_pool_size`, `max_title_length` have functional impact — document changes clearly
- The `empty_messages` and `premium_messages` arrays are user-facing strings; keep them concise and witty

### 4. Installation Safety
- **Never modify** the installation order without testing both modes
- Both modes share `.claude/settings.json` (hook registration); ensure they don't conflict
- Uninstall should cleanly remove: hook references, runtime files, skill directories
- Document any new runtime files that install.sh creates

### 5. Skill Commands
- News mode skills: `add`, `remove`, `list`, `fetch` with `news-fetch` namespace
- Joke Ads skills: `add`, `remove`, `list`, `load`, `premium`, `--skip-ads` with `ad` namespace
- Skill behavior is defined in `.claude/skills/*/SKILL.md`; update it when command behavior changes

### 6. Testing & Verification
- After changes to fetch.sh: manually run it and verify `.claude/pool.json` structure
- After changes to ads.sh: test add/remove/load operations and verify pool updates
- After changes to rotate.sh: verify spinner text updates on at least one tool call
- Check that the hook stays registered in `.claude/settings.json` after installation

## Common Patterns

### Adding a new configuration option
1. Add the key to the relevant `config.json` template in `.claude/skills/*/config.json`
2. Update the corresponding shell script to read and use it
3. Update README.md with documentation of the new option
4. Document default behavior when the key is missing

### Modifying Google News fetch behavior
- The `base_url`, `default_params.hl`, `.gl`, and `.ceid` control the news source
- Changing these affects what headlines appear; test with different locales
- `max_pool_size` and `max_title_length` are truncation settings; verify they don't break long titles

### Adding a new joke ad or hidden feature
- Hardcoded ads live in `.claude/skills/joke-ads/ads.json`
- Hidden features (like `--skip-ads` doubling ads) live in the `ads.sh` logic
- Keep the joke spirit: trap features should be obviously fake when discovered

## Code Quality

### Do
- Keep shell scripts focused on one responsibility (fetch, rotate, manage)
- Use meaningful variable names in Bash (not `x`, `tmp`, etc.)
- Test locale settings (ja vs en) before merging
- Ensure JSON is pretty-printed for readability

### Don't
- Mix mode logic unnecessarily; keep News and Joke Ads separate
- Hardcode file paths; use relative `.claude/` paths
- Assume jq is available without checking; it's a required dependency
- Remove "obvious" features without checking both modes still work

## File Locations

- Shell scripts: `.claude/skills/{news-fetch,joke-ads}/bin/*.sh`
- Skill metadata: `.claude/skills/{news-fetch,joke-ads}/SKILL.md`
- Runtime config: `.claude/config.json` (created by install)
- Spinner pool: `.claude/pool.json` (created at runtime)
- History: `.claude/history.json` (optional, tracks shown items)
- Ads source: `.claude/ads.json` (joke-ads mode only)

## When in Doubt

- Check how the install script sets up these files
- Test both modes after any change to shared components
- Verify `.claude/settings.json` still has the correct hook registration
- Ensure uninstall cleanly removes what install added
