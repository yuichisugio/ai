#!/usr/bin/env bash
# Bitbucket PRのレビューデータを取得する
# Usage: ./fetch_bitbucket.sh <pr_id>
#
# 認証（いずれか一方を設定。両方あればアクセストークンを優先）:
#   1. Atlassian API token（推奨）
#      BITBUCKET_EMAIL     — Atlassianアカウントのメールアドレス
#                            ※Bitbucketのユーザー名では認証できない（401になる）
#      BITBUCKET_API_TOKEN — https://id.atlassian.com/manage-profile/security/api-tokens で
#                            「Create API token with scopes」を選び、appに Bitbucket を指定して発行する。
#                            スコープなしのトークンでは Bitbucket API を利用できない。
#                            必要スコープ: read:pullrequest:bitbucket（PR本体・コメント）
#                                          read:repository:bitbucket（差分のリダイレクト先）
#   2. アクセストークン（リポジトリ / プロジェクト / ワークスペース）
#      BITBUCKET_ACCESS_TOKEN — リポジトリの Settings > Security > Access tokens から
#                               「Pull requests: Read」権限で発行する。
#
# オプションの環境変数（未設定時はgit remoteから自動推定）:
#   BITBUCKET_WORKSPACE    — ワークスペースID
#   BITBUCKET_REPO         — リポジトリスラッグ
#
# 注: app password は 2026-07-28 に完全廃止されたため利用できない。

set -euo pipefail

PR_ID="${1:?使用方法: $0 <pr_id>}"

# 認証方式の決定
CURL_AUTH=()
if [[ -n "${BITBUCKET_ACCESS_TOKEN:-}" ]]; then
	CURL_AUTH=(-H "Authorization: Bearer ${BITBUCKET_ACCESS_TOKEN}")
elif [[ -n "${BITBUCKET_EMAIL:-}" && -n "${BITBUCKET_API_TOKEN:-}" ]]; then
	CURL_AUTH=(-u "${BITBUCKET_EMAIL}:${BITBUCKET_API_TOKEN}")
else
	echo "[ERROR] Bitbucketの認証情報が未設定です。以下のいずれかを環境変数に設定してください。" >&2
	echo "  (1) BITBUCKET_EMAIL（Atlassianアカウントのメールアドレス）と BITBUCKET_API_TOKEN" >&2
	echo "      https://id.atlassian.com/manage-profile/security/api-tokens で" >&2
	echo "      「Create API token with scopes」からappに Bitbucket を指定して発行する。" >&2
	echo "      必要スコープ: read:pullrequest:bitbucket と read:repository:bitbucket" >&2
	echo "  (2) BITBUCKET_ACCESS_TOKEN（リポジトリ/プロジェクト/ワークスペースのアクセストークン）" >&2
	if [[ -n "${BITBUCKET_APP_PASSWORD:-}" || -n "${BITBUCKET_USER:-}" ]]; then
		echo "" >&2
		echo "[NOTE] BITBUCKET_USER / BITBUCKET_APP_PASSWORD が設定されていますが、" >&2
		echo "       app password は 2026-07-28 に廃止済みで認証できません。上記へ移行してください。" >&2
	fi
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

BASE="https://api.bitbucket.org/2.0/repositories/$WORKSPACE/$REPO_SLUG"

# Bitbucket APIを叩いてレスポンスボディを標準出力に流す。
# 失敗時はHTTPステータスから原因を切り分けたエラーを標準エラーに出して1を返す。
# Usage: bb_get <BASEからの相対パス> [追加のcurlオプション...]
bb_get() {
	local path="$1"
	shift
	local body status
	body=$(mktemp)
	# -f を付けないのはHTTPステータスを自前で判定するため
	status=$(curl -s -o "$body" -w '%{http_code}' "${CURL_AUTH[@]}" "$@" "$BASE$path") || {
		rm -f "$body"
		echo "[ERROR] $BASE$path への接続に失敗しました。ネットワークを確認してください。" >&2
		return 1
	}

	if [[ "$status" == "200" ]]; then
		cat "$body"
		rm -f "$body"
		return 0
	fi

	rm -f "$body"
	case "$status" in
	401)
		echo "[ERROR] 認証に失敗しました（401）。次を確認してください。" >&2
		echo "        ・BITBUCKET_EMAIL がBitbucketのユーザー名になっていないか（メールアドレスが必要）" >&2
		echo "        ・APIトークンがスコープ付きで発行されているか（スコープなしは利用不可）" >&2
		echo "        ・トークンが失効していないか" >&2
		;;
	403)
		echo "[ERROR] 権限が不足しています（403）。トークンのスコープを確認してください。" >&2
		echo "        必要スコープ: read:pullrequest:bitbucket と read:repository:bitbucket" >&2
		;;
	404)
		echo "[ERROR] 対象が見つかりません（404）。PR ID とリポジトリ（$WORKSPACE/$REPO_SLUG）を確認してください。" >&2
		echo "        非公開リポジトリへの権限がない場合も404が返ります。" >&2
		;;
	555)
		echo "[ERROR] Bitbucket側でタイムアウトしました（555）。差分が大きすぎる可能性があります。" >&2
		;;
	*)
		echo "[ERROR] APIがHTTP $status を返しました: $BASE$path" >&2
		;;
	esac
	return 1
}

echo "=========================================="
echo "## PR基本情報"
echo "=========================================="
if ! PR_JSON=$(bb_get "/pullrequests/$PR_ID"); then
	echo "[ERROR] PR情報の取得に失敗しました。上記のエラーメッセージを確認してください。" >&2
	exit 1
fi
printf '%s' "$PR_JSON" |
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
"

echo ""
echo "=========================================="
echo "## レビューコメント（インライン含む）"
echo "=========================================="
if ! COMMENTS_JSON=$(bb_get "/pullrequests/$PR_ID/comments?pagelen=100"); then
	echo "[ERROR] コメントの取得に失敗しました。上記のエラーメッセージを確認してください。" >&2
	COMMENTS_JSON='{"values": []}'
fi
printf '%s' "$COMMENTS_JSON" |
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
"

echo ""
echo "=========================================="
echo "## PR差分"
echo "=========================================="
# diffは同一ホスト内の差分エンドポイントへ302で転送されるため -L が必須
bb_get "/pullrequests/$PR_ID/diff" -L ||
	echo "(差分の取得に失敗しました)"
