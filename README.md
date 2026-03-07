# news-spinner

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

> Replace Claude Code's spinner text with live Google News headlines.

**[日本語](#日本語) | English**

news-spinner replaces the "Working…" spinner verbs shown during Claude Code inference with real headlines from Google News. Every tool call rotates a fresh headline into the spinner, turning wait time into a mini news ticker.

## Demo

On first install, the spinner is seeded with fake sponsor ads:
```
⠋ ☕ この推論はスターバックスの提供でお送りしています
⠙ 📎 Clippy™ — お困りのようですね？月額$9.99
⠹ 💊 頭痛にバファリン — Claude の幻覚にも効きます※個人の感想
```

After fetching real news with `/news-spinner <keyword>`:
```
⠋ Tesla unveils new AI chip at CES
⠙ OpenAI announces GPT-5 release date
⠹ Japan's cherry blossom season starts early
```

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `bash` (v4+), `curl`, `jq`

## Installation

### Quick Install (one-liner)

```bash
git clone https://github.com/Taichi-Ibi/news-spinner.git
cd news-spinner
curl -fsSL https://raw.githubusercontent.com/Taichi-Ibi/news-spinner/main/.claude/skills/news-spinner/bin/install.sh | bash
```

Or if you already have a `.claude/` directory in your project:

```bash
curl -fsSL https://raw.githubusercontent.com/Taichi-Ibi/news-spinner/main/.claude/skills/news-spinner/bin/install.sh | bash
```

The installer downloads the skill into your project's `.claude/skills/` directory. All settings and runtime data are stored under `.claude/skills/news-spinner/runtime/` (gitignored).
It also appends news-spinner-specific ignore rules to your project's `.gitignore` to avoid dirtying your repository with runtime files.

**Restart Claude Code after installation to activate the hook.**

## Usage

### Via Claude Code skill (recommended)

```
/news-spinner                        # interactive: ask for keywords
/news-spinner AI                     # fetch headlines for "AI"
/news-spinner Claude ChatGPT Gemini  # fetch multiple keywords at once
/news-spinner --since 2026-03-01 AI  # fetch headlines since a date
/news-spinner clear                  # clear the spinner pool
/news-spinner weave on               # enable W&B Weave tracking
/news-spinner weave off              # disable W&B Weave tracking
/news-spinner uninstall              # safely uninstall and remove the skill directory
```

### Via shell

```bash
bash .claude/skills/news-spinner/bin/fetch.sh "AI"
bash .claude/skills/news-spinner/bin/fetch.sh "Claude Code" "ChatGPT"
bash .claude/skills/news-spinner/bin/fetch.sh --since 2026-03-01 "高市"
bash .claude/skills/news-spinner/bin/fetch.sh clear
```

## How It Works

1. **fetch.sh** — Fetches headlines from Google News RSS and stores them in `runtime/pool.json`.
2. **rotate.sh** — Registered as a `PostToolUse` hook. On every tool call it picks a random headline from the pool and sets it as the spinner text.
3. When the pool is empty, a configurable placeholder message is displayed.

```
Google News RSS
     │
     ▼
  fetch.sh ──▶ runtime/pool.json ──▶ rotate.sh ──▶ spinnerVerbs
                                          ▲
                                PostToolUse hook
```

## Configuration

Runtime config is stored in `.claude/skills/news-spinner/runtime/config.json` (created from the template on install). Edit it to customize behavior:

| Key | Default | Description |
|-----|---------|-------------|
| `base_url` | `https://news.google.com/rss/search` | Google News RSS endpoint |
| `default_params.hl` | `ja` | Language code |
| `default_params.gl` | `JP` | Country code |
| `default_params.ceid` | `JP:ja` | Edition ID |
| `max_pool_size` | `50` | Maximum headlines in pool |
| `max_title_length` | `40` | Truncate titles longer than this |
| `empty_messages` | `["No news... run /news-spinner <keyword>"]` | Shown when pool is empty |

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

## W&B Weave Tracking

news-spinner optionally logs fetch operations to [Weights & Biases Weave](https://wandb.ai/site/weave) for observability.

### Setup

```bash
# Create a virtual environment in the project root
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install weave wandb

# Set your W&B API key (add to ~/.zshrc or ~/.bashrc to persist)
export WANDB_API_KEY=your_api_key
```

> The `.venv/` directory is gitignored.

### Enable/disable

```
/news-spinner weave on
/news-spinner weave off
```

Weave is **off by default**. When enabled, each fetch is logged as a Weave op with:
- **Input**: keywords, date filter, locale, pool size before fetch
- **Output**: keyword count, headlines added, pool size after, new headline details (title, link, pubDate, source)

## Project Structure

```
news-spinner/
├── LICENSE
├── README.md
└── .claude/
    ├── settings.json              # Claude Code project settings
    └── skills/
        └── news-spinner/
            ├── SKILL.md
            ├── templates/
            │   ├── config.json    # default config (git-tracked)
            │   ├── state.json     # default state (git-tracked)
            │   └── ads.json       # initial joke ads (seeded into pool on install)
            ├── bin/
            │   ├── install.sh
            │   ├── uninstall.sh
            │   ├── fetch.sh
            │   ├── rotate.sh
            │   └── weave_track.py
            └── runtime/           # user-local, gitignored
                ├── config.json
                ├── state.json
                ├── pool.json
                └── history.json
```

## Uninstall

```bash
/news-spinner uninstall
```

Or via the one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/Taichi-Ibi/news-spinner/main/uninstall.sh | bash
```

This safely removes the news-spinner hook and runtime files, then deletes `.claude/skills/news-spinner/`.

---

## 日本語

Claude Code の spinnerVerbs（推論中に表示される「Working…」等のテキスト）を Google News のヘッドラインに置き換えるツールです。

インストール直後はジョーク広告がスピナーに表示されます。`/news-spinner <キーワード>` で本物のニュースに切り替えられます。

設定・データはすべてプロジェクトの `.claude/skills/news-spinner/runtime/` ディレクトリに保存されます（gitignore済み）。

### 必要なもの

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `bash` (v4以上)、`curl`、`jq`

### インストール

#### ワンライナー（推奨）

```bash
git clone https://github.com/Taichi-Ibi/news-spinner.git
cd news-spinner
curl -fsSL https://raw.githubusercontent.com/Taichi-Ibi/news-spinner/main/.claude/skills/news-spinner/bin/install.sh | bash
```

または既に `.claude/` ディレクトリがあるプロジェクトなら：

```bash
curl -fsSL https://raw.githubusercontent.com/Taichi-Ibi/news-spinner/main/.claude/skills/news-spinner/bin/install.sh | bash
```

**インストール後、Claude Code を再起動してください（hook を有効化するため）。**

### 使い方

#### Claude Code スキル（推奨）

```
/news-spinner                        → 対話的にキーワードを入力
/news-spinner AI                     → 「AI」のニュースを取得
/news-spinner Claude ChatGPT Gemini  → 複数キーワードを一度に取得
/news-spinner --since 2026-03-01 AI  → 指定日以降のニュースを取得
/news-spinner clear                  → プールをクリア
/news-spinner weave on               → W&B Weave トラッキングを有効化
/news-spinner weave off              → W&B Weave トラッキングを無効化
/news-spinner uninstall              → 安全にアンインストールしてスキルディレクトリも削除
```

#### シェルから直接

```bash
bash .claude/skills/news-spinner/bin/fetch.sh "AI"
bash .claude/skills/news-spinner/bin/fetch.sh "Claude Code" "ChatGPT"
bash .claude/skills/news-spinner/bin/fetch.sh --since 2026-03-01 "高市"
bash .claude/skills/news-spinner/bin/fetch.sh clear
```

### W&B Weave トラッキング（オプション）

```bash
# プロジェクトルートに仮想環境を作成
python3 -m venv .venv
source .venv/bin/activate

pip install weave wandb
export WANDB_API_KEY=your_api_key
```

有効化・無効化：

```
/news-spinner weave on
/news-spinner weave off
```

### アンインストール

```
/news-spinner uninstall
```

## License

[MIT](LICENSE)
