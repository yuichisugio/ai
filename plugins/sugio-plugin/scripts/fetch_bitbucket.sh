#!/usr/bin/env bash
# Bitbucket PRのレビューデータを取得する
# Usage: ./fetch_bitbucket.sh <pr_id>
#
# 必要な環境変数:
#   BITBUCKET_USER         — Bitbucketユーザー名
#   BITBUCKET_APP_PASSWORD — アプリパスワード（Settings > App passwords）
# オプションの環境変数（未設定時はgit remoteから自動推定）:
#   BITBUCKET_WORKSPACE    — ワークスペースID
#   BITBUCKET_REPO         — リポジトリスラッグ

set -euo pipefail

PR_ID="${1:?使用方法: $0 <pr_id>}"

# 認証情報の確認
if [[ -z "${BITBUCKET_USER:-}" || -z "${BITBUCKET_APP_PASSWORD:-}" ]]; then
	echo "[ERROR] BITBUCKET_USER と BITBUCKET_APP_PASSWORD を環境変数に設定してください。" >&2
	echo "        Bitbucket の Settings > App passwords からアプリパスワードを発行できます。" >&2
	exit 1
fi

# ワークスペースとリポジトリをgit remoteから自動推定
ORIGIN_URL=$(git remote get-url origin 2>/dev/null || echo "")
WORKSPACE="${BITBUCKET_WORKSPACE:-$(echo "$ORIGIN_URL" | sed 's/.*bitbucket.org[:/]//' | cut -d'/' -f1)}"
REPO_SLUG="${BITBUCKET_REPO:-$(echo "$ORIGIN_URL" | sed 's/.*bitbucket.org[:/]//' | cut -d'/' -f2 | sed 's/\.git$//')}"

if [[ -z "$WORKSPACE" || -z "$REPO_SLUG" ]]; then
	echo "[ERROR] ワークスペースまたはリポジトリを特定できませんでした。" >&2
	echo "        BITBUCKET_WORKSPACE と BITBUCKET_REPO を環境変数に設定してください。" >&2
	exit 1
fi

AUTH="${BITBUCKET_USER}:${BITBUCKET_APP_PASSWORD}"
BASE="https://api.bitbucket.org/2.0/repositories/$WORKSPACE/$REPO_SLUG"

echo "=========================================="
echo "## PR基本情報"
echo "=========================================="
curl -sf -u "$AUTH" "$BASE/pullrequests/$PR_ID" |
	python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'タイトル: {d.get(\"title\", \"(不明)\")}')
print(f'PR番号: {d.get(\"id\", \"(不明)\")}')
src = d.get('source', {}).get('branch', {}).get('name', '')
dst = d.get('destination', {}).get('branch', {}).get('name', '')
print(f'ブランチ: {src} → {dst}')
author = d.get('author', {}).get('display_name') or d.get('author', {}).get('nickname', '(不明なユーザー)')
print(f'作成者: {author}')
print(f'状態: {d.get(\"state\", \"(不明)\")}')
print(f'\n説明:\n{d.get(\"description\", \"\")}')
" || {
	echo "[ERROR] PR情報の取得に失敗しました。PR IDと認証情報を確認してください。" >&2
	exit 1
}

echo ""
echo "=========================================="
echo "## レビューコメント（インライン含む）"
echo "=========================================="
curl -sf -u "$AUTH" "$BASE/pullrequests/$PR_ID/comments?pagelen=100" |
	python3 -c "
import json, sys
d = json.load(sys.stdin)
comments = d.get('values', [])
if not comments:
    print('(コメントなし)')
for i, c in enumerate(comments):
    inline = c.get('inline', {})
    path = inline.get('path', 'general')
    line = inline.get('to', '')
    loc = f'{path}:{line}' if line else path
    author = c.get('user', {}).get('display_name') or c.get('user', {}).get('nickname', '(不明なユーザー)')
    body = c.get('content', {}).get('raw', '(本文なし)')
    print(f'[{loc}] {author}:\n{body}\n---')
" || echo "[ERROR] コメントのパースに失敗しました。上記のエラーメッセージを確認してください。" >&2

echo ""
echo "=========================================="
echo "## PR差分"
echo "=========================================="
curl -sf -u "$AUTH" "$BASE/pullrequests/$PR_ID/diff" 2>/dev/null ||
	echo "(差分の取得に失敗しました)"
