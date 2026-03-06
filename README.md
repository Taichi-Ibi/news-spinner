# NewsSpinner

Claude Code の spinnerVerbs（推論中に表示される「Working…」等のテキスト）を Google News のヘッドラインに置き換えるツール。

## 依存

- `bash`
- `curl`
- `jq`

## インストール

```bash
git clone https://github.com/Taichi-Ibi/NewsSpinner.git
cd NewsSpinner
bash bin/install.sh            # キーワードなし（後から追加）
bash bin/install.sh AI LLM     # キーワード付きでインストール
```

インストール後、Claude Code を再起動してください（hook を有効化するため）。

## 使い方

### Claude Code スキル（推奨）

```
/news-fetch              → 対話的にフィード管理
/news-fetch add AI       → 「AI」のフィードを追加
/news-fetch remove AI    → 「AI」のフィードを削除
/news-fetch list         → 登録済みフィード一覧
/news-fetch fetch        → ニュース取得
```

### シェルから直接

```bash
# フィード管理
bash ~/.newsspinner/bin/fetch.sh add "AI"
bash ~/.newsspinner/bin/fetch.sh add "Claude Code"
bash ~/.newsspinner/bin/fetch.sh list
bash ~/.newsspinner/bin/fetch.sh remove "AI"

# ニュース取得
bash ~/.newsspinner/bin/fetch.sh

# 手動ローテーション
bash ~/.newsspinner/bin/rotate.sh
```

## 仕組み

1. **fetch.sh** — Google News RSS からヘッドラインを取得し `pool.json` に蓄積
2. **rotate.sh** — PostToolUse hook で自動実行。プールからランダムに1件選び spinner に表示
3. プールが空になると「ニュース切れ！」メッセージを表示

### Google News RSS

フィードURL形式: `https://news.google.com/rss/search?q=<keyword>&hl=ja&gl=JP&ceid=JP:ja`

言語・地域は `~/.newsspinner/config.json` の `default_params` で変更可能。

## 設定

`~/.newsspinner/config.json`:

```json
{
  "feeds": [],
  "base_url": "https://news.google.com/rss/search",
  "default_params": {
    "hl": "ja",
    "gl": "JP",
    "ceid": "JP:ja"
  },
  "max_pool_size": 50,
  "max_title_length": 40,
  "empty_messages": [
    "📰 ニュース切れ！ /news-fetch して",
    "No news... run /news-fetch",
    "Waiting for fresh headlines"
  ]
}
```

## アンインストール

```bash
bash ~/.newsspinner/bin/uninstall.sh
```

Claude Code を再起動して完了です。
