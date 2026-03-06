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

### News mode (Google News headlines)

```bash
git clone https://github.com/Taichi-Ibi/NewsSpinner.git
cd NewsSpinner
bash skills/news-fetch/bin/install.sh              # no initial keywords
bash skills/news-fetch/bin/install.sh AI LLM        # with initial keywords
```

### Joke Ads mode (fake sponsor ads)

```bash
git clone https://github.com/Taichi-Ibi/NewsSpinner.git
cd NewsSpinner
bash skills/joke-ads/bin/install.sh
```

Restart Claude Code after installation to activate the hook.

> **Note:** Both modes share `~/.newsspinner/` and the same `PostToolUse` hook. Install one at a time, or uninstall the other first.

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
~/.newsspinner/bin/fetch.sh add "AI"
~/.newsspinner/bin/fetch.sh add "Claude Code"
~/.newsspinner/bin/fetch.sh list
~/.newsspinner/bin/fetch.sh remove "AI"
~/.newsspinner/bin/fetch.sh                         # fetch all feeds
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
~/.newsspinner/bin/ads.sh list                      # list all ads
~/.newsspinner/bin/ads.sh add "🍣 スシロー — 回転寿司のように回転するコード"
~/.newsspinner/bin/ads.sh load                      # load ads into pool
~/.newsspinner/bin/ads.sh --skip-ads                # "skip" ads (try it!)
~/.newsspinner/bin/ads.sh premium                   # go premium (try it!)
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
  fetch.sh ──▶ pool.json ──▶ rotate.sh ──▶ spinnerVerbs
                                ▲
                      PostToolUse hook
```

### Joke Ads mode

1. **ads.json** — Local pool of hardcoded fake sponsor ads (user can add custom ones).
2. **ads.sh** — Loads ads from `ads.json` into `pool.json`. Handles add/remove/premium/--skip-ads.
3. **rotate.sh** — Same mechanism: picks a random ad from the pool on every tool call.

```
ads.json (local)
     │
     ▼
  ads.sh ──▶ pool.json ──▶ rotate.sh ──▶ spinnerVerbs
                              ▲
                    PostToolUse hook
```

## Configuration

### News mode

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

Custom ads can be added to `~/.newsspinner/ads.json` directly or via `ads.sh add`.

## Project Structure

```
NewsSpinner/
├── LICENSE
├── README.md
├── skills/news-fetch/             # News mode
│   ├── SKILL.md
│   ├── config.json
│   └── bin/
│       ├── install.sh
│       ├── uninstall.sh
│       ├── fetch.sh
│       └── rotate.sh
└── skills/joke-ads/               # Joke Ads mode (NEW!)
    ├── SKILL.md
    ├── config.json
    ├── ads.json                   # hardcoded fake sponsor ads
    └── bin/
        ├── install.sh
        ├── uninstall.sh
        ├── ads.sh                 # ad management & joke features
        └── rotate.sh
```

## Uninstall

```bash
~/.newsspinner/bin/uninstall.sh
```

This removes all installed files, the Claude Code hook, and spinner overrides.

---

## 日本語

Claude Code の spinnerVerbs（推論中に表示される「Working…」等のテキスト）を Google News のヘッドラインに置き換えるツールです。

**NEW: ジョーク広告モード** — スピナーに架空のスポンサー広告を表示してウケを狙えます。`--skip-ads`（広告が倍増）、Premiumモード（何も起きない）、`ad_frequency`設定（完全に無視される）などのジョーク機能付き。

### 必要なもの

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `bash` (v4以上)、`curl`、`jq`

### インストール

#### ニュースモード

```bash
git clone https://github.com/Taichi-Ibi/NewsSpinner.git
cd NewsSpinner
bash skills/news-fetch/bin/install.sh              # キーワードなし
bash skills/news-fetch/bin/install.sh AI LLM        # キーワード付き
```

#### ジョーク広告モード

```bash
git clone https://github.com/Taichi-Ibi/NewsSpinner.git
cd NewsSpinner
bash skills/joke-ads/bin/install.sh
```

インストール後、Claude Code を再起動してください（hook を有効化するため）。

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
~/.newsspinner/bin/fetch.sh add "AI"
~/.newsspinner/bin/fetch.sh add "Claude Code"
~/.newsspinner/bin/fetch.sh list
~/.newsspinner/bin/fetch.sh remove "AI"
~/.newsspinner/bin/fetch.sh                         # 全フィードからニュース取得
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
~/.newsspinner/bin/ads.sh list                      # 全広告の一覧
~/.newsspinner/bin/ads.sh add "🍣 スシロー — 回転寿司のように回転するコード"
~/.newsspinner/bin/ads.sh load                      # 広告をプールに読み込み
~/.newsspinner/bin/ads.sh --skip-ads                # 広告を「スキップ」（試してみて！）
~/.newsspinner/bin/ads.sh premium                   # Premium化（試してみて！）
```

#### ジョーク広告の隠し機能

| 機能 | 期待される動作 | 実際の動作 |
|------|---------------|-----------|
| `--skip-ads` | 広告が消える | 広告が**倍増**する |
| `premium` | 広告なし体験 | 皮肉なメッセージが出て広告はそのまま |
| `ad_frequency` | 広告頻度の制御 | 設定値は完全に無視される |

### 仕組み

#### ニュースモード

1. **fetch.sh** — Google News RSS からヘッドラインを取得し `pool.json` に蓄積
2. **rotate.sh** — `PostToolUse` hook として登録。ツール実行のたびにプールからランダムに1件選び spinner に表示
3. プールが空になると設定済みのプレースホルダーメッセージを表示

#### ジョーク広告モード

1. **ads.json** — ハードコードされた架空スポンサー広告のプール（カスタム追加可能）
2. **ads.sh** — `ads.json` から `pool.json` へ広告を読み込み。追加/削除/Premium/--skip-ads を処理
3. **rotate.sh** — 同じ仕組み：ツール実行のたびにプールからランダムに1件選び spinner に表示

### アンインストール

```bash
~/.newsspinner/bin/uninstall.sh
```

## License

[MIT](LICENSE)
