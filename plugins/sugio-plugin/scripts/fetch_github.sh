#!/usr/bin/env bash
# GitHub PRのレビューデータを取得する
# Usage: ./fetch_github.sh <pr_id>

set -euo pipefail

PR_ID="${1:?使用方法: $0 <pr_id>}"

# gh CLI 認証確認
if ! gh auth status &>/dev/null; then
	echo "[ERROR] GitHub CLI が未認証です。'gh auth login' を実行してください。" >&2
	exit 1
fi

REPO=$(gh repo view --json owner,name -q '"\(.owner.login)/\(.name)"')

echo "=========================================="
echo "## PR基本情報"
echo "=========================================="
gh pr view "$PR_ID" --json title,body,number,headRefName,baseRefName,author \
	--jq '"タイトル: \(.title)\nPR番号: \(.number)\nブランチ: \(.headRefName) → \(.baseRefName)\n作成者: \(.author.login)\n\n説明:\n\(.body)"'

echo ""
echo "=========================================="
echo "## レビューコメント（承認・却下）"
echo "=========================================="
gh pr view "$PR_ID" --json reviews \
	--jq '.reviews[] | "[\(.state)] \(.author.login):\n\(.body)\n---"' 2>/dev/null ||
	echo "(レビューコメントなし)"

echo ""
echo "=========================================="
echo "## インラインコメント（ファイル・行番号付き）"
echo "=========================================="
gh api "repos/$REPO/pulls/$PR_ID/comments" \
	--jq '.[] | "[\(.path):\(.line // "general")] \(.user.login):\n\(.body)\n---"' 2>/dev/null ||
	echo "(インラインコメントなし)"

echo ""
echo "=========================================="
echo "## PR差分"
echo "=========================================="
gh pr diff "$PR_ID"
