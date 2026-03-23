# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository is a **Claude Code plugin development workspace**. It contains a private plugin marketplace (`sugio-marketplace`) with two plugins:

- `sugio-plugin` — 本番用プラグイン（スキル・エージェント・コマンド・フック・MCP・LSPを含む）
- `test-plugin` — マーケットプレイス動作検証用プラグイン

## Plugin Development

### 変更後のリロード

プラグインのファイルを変更した後は必ず `/reload-plugins` を実行してリロードする。

### Plugin Structure

各プラグインは以下の構成を持つ：

```
plugins/<plugin-name>/
  .claude-plugin/plugin.json   # プラグインメタデータ（name, version, author等）
  skills/<skill-name>/SKILL.md # スキル定義（フロントマターにname/descriptionが必須）
  agents/<agent-name>.md       # エージェント定義（readonly/is_backgroundオプション）
  commands/<command-name>.md   # スラッシュコマンド用プロンプト
  hooks/hooks.json             # イベントフック定義
  settings.json                # プラグイン設定（デフォルトエージェント等）
  .mcp.json                    # MCP サーバー設定
  .lsp.json                    # LSP サーバー設定
```

### Marketplace 登録

`.claude-plugin/marketplace.json` にプラグインエントリを追加することでマーケットプレイスに登録される。`source` フィールドで相対パスを指定する。

### ローカル定義（非プラグイン）

`.agents/` ディレクトリにはプラグインに属さないローカル定義を置く：
- `.agents/skills/` — ローカルスキル
- `.agents/agents/` — ローカルエージェント
- `.agents/commands/` — ローカルコマンド
- `.agents/rules/` — ルール・ドキュメント

## Key Files

| ファイル | 役割 |
|---|---|
| `.claude-plugin/marketplace.json` | マーケットプレイス定義・プラグイン一覧 |
| `plugins/sugio-plugin/hooks/hooks.json` | Notificationフック（macOS通知） |
| `plugins/sugio-plugin/.mcp.json` | chrome-devtools-mcp の設定 |
| `plugins/sugio-plugin/.lsp.json` | gopls（Go言語サーバー）の設定 |

## Skills in sugio-plugin

| スキル | 用途 |
|---|---|
| `identify-explain` | 実装依頼を受けた際、変更箇所をコードから特定して根拠つきで解説する（編集前の調査フェーズ） |
| `apply-pr-feedback` | GitHubまたはBitbucketのPRレビューコメントを取得し、3エージェント並列で修正案を生成・比較する |
| `run-e2e-from-csv` | テスト仕様書CSV（結合テストチェックリスト形式）を読み込み、Chrome in Claude でE2Eテストを実行してMarkdownレポートを出力する |
| `hello-world` | ユーザーへの挨拶デモ用スキル |

## Rules

- 常に日本語で回答する（`AGENTS.md` の指示）
- `review-agent` は `readonly: true, is_background: true` で動作し、`git diff HEAD` を起点にレビューを行う
- 本番ブランチは `production`
