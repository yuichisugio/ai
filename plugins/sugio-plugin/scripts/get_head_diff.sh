#!/usr/bin/env bash
# HEADとの差分（未コミットの変更）を取得する
# Usage: ./get_head_diff.sh

set -euo pipefail

echo "=========================================="
echo "## 変更ファイル一覧"
echo "=========================================="
git diff HEAD --stat

echo ""
echo "=========================================="
echo "## 差分の詳細"
echo "=========================================="
git diff HEAD
