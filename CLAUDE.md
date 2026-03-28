# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

- `sugio-plugin` — 本番用プラグイン（スキル・エージェント・コマンド・フック・MCP・LSPを含む）
- `test-plugin` — マーケットプレイス動作検証用プラグイン

## Rules

- 常に日本語で回答する（`AGENTS.md` の指示）
- `review-agent` は `readonly: true, is_background: true` で動作し、`git diff HEAD` を起点にレビューを行う
- 本番ブランチは `production`
- 作成する対象のベストプラクティスやドキュメントをサブエージェントを使用してよく調査してから実装に取り組んでいください。
