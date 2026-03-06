# NewsSpinner

Claude Code の spinnerVerbs（推論中に表示される「Working…」等のテキスト）を Google News のヘッドラインに置き換えるツール。

## 構成

```
README.md
.gitignore
skills/news-fetch/
  ├── SKILL.md           ← Claude Code スキル定義
  ├── config.json        ← デフォルト設定
  └── bin/
      ├── install.sh     ← セットアップ & hooks 登録
      ├── uninstall.sh   ← クリーン削除
      ├── fetch.sh       ← フィード管理 & ニュース取得
      └── rotate.sh      ← spinner ローテーション (hook で自動実行)
```

## 依存

- `bash`, `curl`, `jq`

## インストール

```bash
git clone https://github.com/Taichi-Ibi/NewsSpinner.git
cd NewsSpinner
bash skills/news-fetch/bin/install.sh            # キーワードなし
bash skills/news-fetch/bin/install.sh AI LLM     # キーワード付き
```

インストール後、Claude Code を再起動してください（hook を有効化するため）。

## 使い方

### Claude Code スキル（推奨）

```
/news-fetch              → 対話的にフィード管理
/news-fetch add AI       → 「AI」のフィードを追加
/news-fetch remove AI    → フィードを削除
/news-fetch list         → 登録済み一覧
/news-fetch fetch        → ニュース取得
```

### シェルから直接

```bash
bash ~/.newsspinner/bin/fetch.sh add "AI"
bash ~/.newsspinner/bin/fetch.sh add "Claude Code"
bash ~/.newsspinner/bin/fetch.sh list
bash ~/.newsspinner/bin/fetch.sh remove "AI"
bash ~/.newsspinner/bin/fetch.sh        # 全フィードからニュース取得
```

## 仕組み

1. **fetch.sh** — Google News RSS からヘッドラインを取得し `pool.json` に蓄積
2. **rotate.sh** — PostToolUse hook で自動実行。プールからランダムに1件選び spinner に表示
3. プールが空になると「ニュース切れ！」メッセージを表示

フィードURL: `https://news.google.com/rss/search?q=<keyword>&hl=ja&gl=JP&ceid=JP:ja`

## アンインストール

```bash
bash ~/.newsspinner/bin/uninstall.sh
```
