# NewsSpinner

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

> Replace Claude Code's spinner text with live Google News headlines.

**[日本語](#日本語) | English**

NewsSpinner replaces the "Working…" spinner verbs shown during Claude Code inference with real headlines from Google News. Every tool call rotates a fresh headline into the spinner, turning wait time into a mini news ticker.

## Demo

```
⠋ Tesla unveils new AI chip at CES [12]
⠙ OpenAI announces GPT-5 release date [11]
⠹ Japan's cherry blossom season starts early [10]
```

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `bash` (v4+), `curl`, `jq`

## Installation

```bash
git clone https://github.com/Taichi-Ibi/NewsSpinner.git
cd NewsSpinner
bash skills/news-fetch/bin/install.sh              # no initial keywords
bash skills/news-fetch/bin/install.sh AI LLM        # with initial keywords
```

Restart Claude Code after installation to activate the hook.

## Usage

### Via Claude Code skill (recommended)

```
/news-fetch              # interactive feed management
/news-fetch add AI       # add a feed for "AI"
/news-fetch remove AI    # remove the feed
/news-fetch list         # show registered feeds
/news-fetch fetch        # fetch new headlines
```

### Via shell

```bash
~/.newsspinner/bin/fetch.sh add "AI"
~/.newsspinner/bin/fetch.sh add "Claude Code"
~/.newsspinner/bin/fetch.sh list
~/.newsspinner/bin/fetch.sh remove "AI"
~/.newsspinner/bin/fetch.sh                         # fetch all feeds
```

## How It Works

1. **fetch.sh** — Fetches headlines from Google News RSS and stores them in `pool.json`.
2. **rotate.sh** — Registered as a `PostToolUse` hook. On every tool call it picks a random headline from the pool and sets it as the spinner text.
3. When the pool is empty, a configurable placeholder message is displayed.

```
Google News RSS
     │
     ▼
  fetch.sh ──▶ pool.json ──▶ rotate.sh ──▶ spinnerVerbs
                                ▲
                      PostToolUse hook
```

## Configuration

After installation, edit `~/.newsspinner/config.json`:

| Key | Default | Description |
|-----|---------|-------------|
| `base_url` | `https://news.google.com/rss/search` | Google News RSS endpoint |
| `default_params.hl` | `ja` | Language code |
| `default_params.gl` | `JP` | Country code |
| `default_params.ceid` | `JP:ja` | Edition ID |
| `max_pool_size` | `50` | Maximum headlines in pool |
| `max_title_length` | `40` | Truncate titles longer than this |
| `empty_messages` | `["No news... run /news-fetch"]` | Shown when pool is empty |

To switch to English (US) news, update the locale parameters:

```json
{
  "default_params": {
    "hl": "en",
    "gl": "US",
    "ceid": "US:en"
  }
}
```

## Project Structure

```
NewsSpinner/
├── LICENSE
├── README.md
└── skills/news-fetch/
    ├── SKILL.md           # Claude Code skill definition
    ├── config.json        # default configuration
    └── bin/
        ├── install.sh     # setup & hook registration
        ├── uninstall.sh   # clean removal
        ├── fetch.sh       # feed management & headline fetching
        └── rotate.sh      # spinner rotation (runs via hook)
```

## Uninstall

```bash
~/.newsspinner/bin/uninstall.sh
```

This removes all installed files, the Claude Code hook, and spinner overrides.

---

## 日本語

Claude Code の spinnerVerbs（推論中に表示される「Working…」等のテキスト）を Google News のヘッドラインに置き換えるツールです。

### 必要なもの

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `bash` (v4以上)、`curl`、`jq`

### インストール

```bash
git clone https://github.com/Taichi-Ibi/NewsSpinner.git
cd NewsSpinner
bash skills/news-fetch/bin/install.sh              # キーワードなし
bash skills/news-fetch/bin/install.sh AI LLM        # キーワード付き
```

インストール後、Claude Code を再起動してください（hook を有効化するため）。

### 使い方

#### Claude Code スキル（推奨）

```
/news-fetch              → 対話的にフィード管理
/news-fetch add AI       → 「AI」のフィードを追加
/news-fetch remove AI    → フィードを削除
/news-fetch list         → 登録済み一覧
/news-fetch fetch        → ニュース取得
```

#### シェルから直接

```bash
~/.newsspinner/bin/fetch.sh add "AI"
~/.newsspinner/bin/fetch.sh add "Claude Code"
~/.newsspinner/bin/fetch.sh list
~/.newsspinner/bin/fetch.sh remove "AI"
~/.newsspinner/bin/fetch.sh                         # 全フィードからニュース取得
```

### 仕組み

1. **fetch.sh** — Google News RSS からヘッドラインを取得し `pool.json` に蓄積
2. **rotate.sh** — `PostToolUse` hook として登録。ツール実行のたびにプールからランダムに1件選び spinner に表示
3. プールが空になると設定済みのプレースホルダーメッセージを表示

### アンインストール

```bash
~/.newsspinner/bin/uninstall.sh
```

## License

[MIT](LICENSE)
