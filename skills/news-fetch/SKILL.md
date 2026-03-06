---
name: news-fetch
description: Manage NewsSpinner feeds and fetch Google News headlines for Claude Code spinner
argument-hint: "[add|remove|list|fetch] [keyword]"
allowed-tools: Bash, AskUserQuestion
---

# NewsSpinner — ニュースフィード管理

Claude Code の spinner（推論中に表示されるテキスト）を Google News のヘッドラインに置き換える NewsSpinner のフィード管理スキル。

## 動作

引数に応じて以下を実行する。

### `$ARGUMENTS` が空の場合

ユーザーに何をしたいか確認する（AskUserQuestion を使う）:
- フィードを追加（キーワードを聞く）
- フィードを削除（既存フィード一覧から選択）
- フィード一覧表示
- ニュースを取得（fetch 実行）

### `add <keyword>` の場合

1. `bash ~/.newsspinner/bin/fetch.sh add "<keyword>"` を実行してフィードを登録
2. 登録後、すぐに fetch するか確認
3. fetch する場合は `bash ~/.newsspinner/bin/fetch.sh` を実行

### `remove <keyword>` の場合

`bash ~/.newsspinner/bin/fetch.sh remove "<keyword>"` を実行

### `list` の場合

`bash ~/.newsspinner/bin/fetch.sh list` を実行して登録済みフィード一覧を表示

### `fetch` の場合

`bash ~/.newsspinner/bin/fetch.sh` を実行して全フィードからニュースを取得

## 重要な注意

- キーワードの追加時、ユーザーに確認してから実行すること
- Google News RSS の URL 形式: `https://news.google.com/rss/search?q=<keyword>&hl=ja&gl=JP&ceid=JP:ja`
- スクリプトは `~/.newsspinner/bin/` にインストールされている
- 未インストールの場合は `bash <repo>/bin/install.sh` を案内する
