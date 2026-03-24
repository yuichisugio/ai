#!/usr/bin/env bash
# production ブランチとカレントブランチの差分を取得する
# Usage: ./get_diff.sh

set -euo pipefail

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ "$CURRENT_BRANCH" = "production" ]; then
	echo "[ERROR] 現在 production ブランチ上です。開発ブランチに切り替えてから実行してください。" >&2
	exit 1
fi

echo "=========================================="
echo "## ブランチ情報"
echo "=========================================="
echo "カレントブランチ: $CURRENT_BRANCH"
echo "比較対象: production"
echo ""

# production ブランチをリモートから最新化（ローカルを直接更新）
echo "[INFO] production ブランチを最新化しています..." >&2
if git fetch origin production 2>/dev/null; then
	git branch -f production origin/production 2>/dev/null || true
	echo "[INFO] production ブランチを最新化しました。" >&2
else
	echo "[WARN] リモートからの fetch に失敗しました。ローカルの production ブランチを使用します。" >&2
fi

MERGE_BASE=$(git merge-base production "$CURRENT_BRANCH" 2>/dev/null || echo "")
if [ -z "$MERGE_BASE" ]; then
	echo "[ERROR] production ブランチとの共通祖先が見つかりません。" >&2
	exit 1
fi

echo "=========================================="
echo "## コミットログ（production からの差分）"
echo "=========================================="
git log --oneline --no-merges "production..$CURRENT_BRANCH"

echo ""
echo "=========================================="
echo "## 変更ファイル一覧"
echo "=========================================="
git diff --stat "production...$CURRENT_BRANCH"

echo ""
echo "=========================================="
echo "## 変更サマリー（ファイルごとのステータス）"
echo "=========================================="
git diff --name-status "production...$CURRENT_BRANCH"

echo ""
echo "=========================================="
echo "## 差分の詳細"
echo "=========================================="
git diff "production...$CURRENT_BRANCH"
