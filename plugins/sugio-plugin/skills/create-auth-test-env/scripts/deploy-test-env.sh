#!/usr/bin/env bash

# Usage: ./deploy-test-env.sh <front|back>

set -euo pipefail

TARGET="${1:-}"

if [[ "$TARGET" != "front" && "$TARGET" != "back" ]]; then
	echo "ERROR: 引数が不正です。'front' または 'back' を指定してください。" >&2
	echo "Usage: $0 <front|back>" >&2
	exit 1
fi

CURRENT_BRANCH=$(git branch --show-current)
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "(不明)")
REPO_NAME=$(basename -s .git "$REMOTE_URL")

echo "====================================="
echo "  デプロイ対象: ${TARGET}"
echo "  リポジトリ  : ${REPO_NAME}"
echo "  現在のブランチ: ${CURRENT_BRANCH}"
echo "====================================="

SUFFIX=$(echo "$CURRENT_BRANCH" | sed "s|^[^/]*/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-||")
TEST_BRANCH="test/$(date +%Y-%m-%d)-${SUFFIX}"

echo "テストブランチ: ${TEST_BRANCH}"
echo ""

git checkout production &&
	git pull origin production &&
	if git show-ref --verify --quiet "refs/heads/${TEST_BRANCH}"; then
		git checkout "$TEST_BRANCH"
	else
		git checkout -b "$TEST_BRANCH"
	fi &&
	git merge "$CURRENT_BRANCH" &&
	git push origin "$TEST_BRANCH"

echo ""
echo "デプロイ完了: ${TEST_BRANCH} をプッシュしました。"
