# NewsSpinner

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

> Replace Claude Code's spinner text with live Google News headlines — or fake sponsor ads.

**[日本語](#日本語) | English**

NewsSpinner replaces the "Working…" spinner verbs shown during Claude Code inference with real headlines from Google News. Every tool call rotates a fresh headline into the spinner, turning wait time into a mini news ticker.

**NEW: Joke Ads mode** — Replace the spinner with fake sponsor ads for a laugh. Features include a `--skip-ads` flag (that doubles the ads), a premium mode (that does nothing), and an `ad_frequency` setting (that is completely ignored).

## Demo

### News mode
```
⠋ Tesla unveils new AI chip at CES [12]
⠙ OpenAI announces GPT-5 release date [11]
⠹ Japan's cherry blossom season starts early [10]
```

### Joke Ads mode
```
⠋ ☕ この推論はスターバックスの提供でお送りしています [12]
⠙ 📎 Clippy Premium™ — お困りのようですね？月額$9.99 [11]
⠹ 💊 頭痛にバファリン — Claude の幻覚にも効きます※個人の感想です [10]
```

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `bash` (v4+), `curl`, `jq`

## Installation

### Quick Install (one-liner)

```bash
git clone https://github.com/Taichi-Ibi/NewsSpinner.git
cd NewsSpinner
curl -fsSL https://raw.githubusercontent.com/Taichi-Ibi/NewsSpinner/main/install.sh | bash
```

Or if you already have a `.claude/` directory in your project:

```bash
curl -fsSL https://raw.githubusercontent.com/Taichi-Ibi/NewsSpinner/main/install.sh | bash
```

The installer downloads skills into your project's `.claude/skills/` directory. All settings and runtime data are stored in `.claude/`.

**Restart Claude Code after installation to activate the hook.**

> **Note:** Both modes share the project's `.claude/` directory and the same `PostToolUse` hook. Install one at a time, or uninstall the other first.

## Usage

### News mode

#### Via Claude Code skill (recommended)

```
/news-fetch              # interactive feed management
/news-fetch add AI       # add a feed for "AI"
/news-fetch remove AI    # remove the feed
/news-fetch list         # show registered feeds
/news-fetch fetch        # fetch new headlines
```

#### Via shell

```bash
bash .claude/skills/news-fetch/bin/fetch.sh add "AI"
bash .claude/skills/news-fetch/bin/fetch.sh add "Claude Code"
bash .claude/skills/news-fetch/bin/fetch.sh list
bash .claude/skills/news-fetch/bin/fetch.sh remove "AI"
bash .claude/skills/news-fetch/bin/fetch.sh          # fetch all feeds
```

### Joke Ads mode

#### Via Claude Code skill (recommended)

```
/ad                      # interactive ad management
/ad add "🍣 your ad"     # add a custom ad
/ad remove "🍣 your ad"  # remove an ad
/ad list                 # show all ads
/ad load                 # reload ads into spinner pool
/ad premium              # activate "premium" (it's a trap)
/ad --skip-ads           # skip ads (it's also a trap)
```

#### Via shell

```bash
bash .claude/skills/joke-ads/bin/ads.sh list
bash .claude/skills/joke-ads/bin/ads.sh add "🍣 スシロー — 回転寿司のように回転するコード"
bash .claude/skills/joke-ads/bin/ads.sh load
bash .claude/skills/joke-ads/bin/ads.sh --skip-ads   # "skip" ads (try it!)
bash .claude/skills/joke-ads/bin/ads.sh premium      # go premium (try it!)
```

### Joke Ads — hidden features

| Feature | What you'd expect | What actually happens |
|---------|-------------------|----------------------|
| `--skip-ads` | Ads disappear | Ads are **doubled** |
| `premium` | Ad-free experience | Snarky message, ads remain |
| `ad_frequency` | Control ad rate | Setting is completely ignored |

## How It Works

### News mode

1. **fetch.sh** — Fetches headlines from Google News RSS and stores them in `pool.json`.
2. **rotate.sh** — Registered as a `PostToolUse` hook. On every tool call it picks a random headline from the pool and sets it as the spinner text.
3. When the pool is empty, a configurable placeholder message is displayed.

```
Google News RSS
     │
     ▼
  fetch.sh ──▶ .claude/pool.json ──▶ rotate.sh ──▶ spinnerVerbs
                                          ▲
                                PostToolUse hook
```

### Joke Ads mode

1. **ads.json** — Local pool of hardcoded fake sponsor ads (user can add custom ones).
2. **ads.sh** — Loads ads from `ads.json` into `pool.json`. Handles add/remove/premium/--skip-ads.
3. **rotate.sh** — Same mechanism: picks a random ad from the pool on every tool call.

```
.claude/ads.json (local)
     │
     ▼
  ads.sh ──▶ .claude/pool.json ──▶ rotate.sh ──▶ spinnerVerbs
                                        ▲
                              PostToolUse hook
```

## Configuration

All runtime data is stored in the project's `.claude/` directory:

| File | Description |
|------|-------------|
| `.claude/settings.json` | Claude Code settings (hook registered here) |
| `.claude/config.json` | NewsSpinner configuration |
| `.claude/pool.json` | Current spinner headline/ad pool |
| `.claude/history.json` | Previously shown headlines/ads |
| `.claude/ads.json` | Joke Ads source file (ads mode only) |

### News mode

Edit `.claude/config.json`:

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

### Joke Ads mode

| Key | Default | Description |
|-----|---------|-------------|
| `max_pool_size` | `50` | Maximum ads in pool |
| `max_ad_length` | `60` | Truncate ads longer than this |
| `ad_frequency` | `"normal"` | Ad display frequency (completely ignored) |
| `premium` | `false` | Premium mode toggle (does nothing useful) |
| `empty_messages` | `[...]` | Shown when pool is empty |
| `premium_messages` | `[...]` | Snarky messages for premium users |
| `skip_ads_messages` | `[...]` | Messages when --skip-ads is used |

Custom ads can be added to `.claude/ads.json` directly or via `ads.sh add`.

## Project Structure

```
NewsSpinner/
├── LICENSE
├── README.md
└── .claude/
    ├── settings.json              # Claude Code project settings
    ├── skills/
    │   ├── news-fetch/            # News mode
    │   │   ├── SKILL.md
    │   │   ├── config.json        # default config template
    │   │   └── bin/
    │   │       ├── install.sh
    │   │       ├── uninstall.sh
    │   │       ├── fetch.sh
    │   │       └── rotate.sh
    │   └── joke-ads/              # Joke Ads mode
    │       ├── SKILL.md
    │       ├── config.json        # default config template
    │       ├── ads.json           # hardcoded fake sponsor ads
    │       └── bin/
    │           ├── install.sh
    │           ├── uninstall.sh
    │           ├── ads.sh
    │           └── rotate.sh
    │
    │   (created by install.sh)
    ├── config.json                # runtime config
    ├── pool.json                  # spinner pool
    ├── history.json               # shown headlines/ads
    └── ads.json                   # ads source (joke-ads mode)
```

## Uninstall

```bash
bash .claude/skills/news-fetch/bin/uninstall.sh   # news mode
bash .claude/skills/joke-ads/bin/uninstall.sh     # joke-ads mode
```

This removes the Claude Code hook, spinner overrides, and runtime data files from `.claude/`.

---

## 日本語

Claude Code の spinnerVerbs（推論中に表示される「Working…」等のテキスト）を Google News のヘッドラインに置き換えるツールです。

**NEW: ジョーク広告モード** — スピナーに架空のスポンサー広告を表示してウケを狙えます。`--skip-ads`（広告が倍増）、Premiumモード（何も起きない）、`ad_frequency`設定（完全に無視される）などのジョーク機能付き。

設定・データはすべてプロジェクトの `.claude/` ディレクトリに保存されます。

### 必要なもの

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `bash` (v4以上)、`curl`、`jq`

### インストール

#### ワンライナー（推奨）

```bash
git clone https://github.com/Taichi-Ibi/NewsSpinner.git
cd NewsSpinner
curl -fsSL https://raw.githubusercontent.com/Taichi-Ibi/NewsSpinner/main/install.sh | bash
```

または既に `.claude/` ディレクトリがあるプロジェクトなら：

```bash
curl -fsSL https://raw.githubusercontent.com/Taichi-Ibi/NewsSpinner/main/install.sh | bash
```

インストーラーはスキルをプロジェクトの `.claude/skills/` にダウンロードします。設定・データはすべて `.claude/` ディレクトリに保存されます。

**インストール後、Claude Code を再起動してください（hook を有効化するため）。**

### 使い方

#### ニュースモード — Claude Code スキル（推奨）

```
/news-fetch              → 対話的にフィード管理
/news-fetch add AI       → 「AI」のフィードを追加
/news-fetch remove AI    → フィードを削除
/news-fetch list         → 登録済み一覧
/news-fetch fetch        → ニュース取得
```

#### ニュースモード — シェルから直接

```bash
bash .claude/skills/news-fetch/bin/fetch.sh add "AI"
bash .claude/skills/news-fetch/bin/fetch.sh add "Claude Code"
bash .claude/skills/news-fetch/bin/fetch.sh list
bash .claude/skills/news-fetch/bin/fetch.sh remove "AI"
bash .claude/skills/news-fetch/bin/fetch.sh                  # 全フィードからニュース取得
```

#### ジョーク広告モード — Claude Code スキル（推奨）

```
/ad                      → 対話的に広告管理
/ad add "🍣 広告テキスト" → カスタム広告を追加
/ad list                 → 全広告の一覧
/ad load                 → 広告をプールに読み込み
/ad premium              → Premium体験を有効化（罠です）
/ad --skip-ads           → 広告をスキップ（これも罠です）
```

#### ジョーク広告モード — シェルから直接

```bash
bash .claude/skills/joke-ads/bin/ads.sh list
bash .claude/skills/joke-ads/bin/ads.sh add "🍣 スシロー — 回転寿司のように回転するコード"
bash .claude/skills/joke-ads/bin/ads.sh load
bash .claude/skills/joke-ads/bin/ads.sh --skip-ads           # 広告を「スキップ」（試してみて！）
bash .claude/skills/joke-ads/bin/ads.sh premium              # Premium化（試してみて！）
```

#### ジョーク広告の隠し機能

| 機能 | 期待される動作 | 実際の動作 |
|------|---------------|-----------|
| `--skip-ads` | 広告が消える | 広告が**倍増**する |
| `premium` | 広告なし体験 | 皮肉なメッセージが出て広告はそのまま |
| `ad_frequency` | 広告頻度の制御 | 設定値は完全に無視される |

### アンインストール

```bash
bash .claude/skills/news-fetch/bin/uninstall.sh   # ニュースモード
bash .claude/skills/joke-ads/bin/uninstall.sh     # ジョーク広告モード
```

## License

[MIT](LICENSE)
