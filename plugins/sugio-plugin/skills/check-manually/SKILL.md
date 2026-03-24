---
name: check-manually
description: テスト仕様書（CSV・Markdownなど）とサービスURLを受け取り、Claude in ChromeでE2Eテストを実行してMarkdownレポートを出力する。引数にCSVファイルパスまたはMarkdownファイルパスとURLを指定する。テスト仕様書が省略された場合はカレントブランチとproductionブランチの差分から自動生成する。テスト実施・QA確認・結合テスト・ブラウザ動作確認を依頼されたときに使用する。手動テストの自動実行、テストケースを元にした画面操作確認にも積極的に使用する。
argument-hint: [url, spec_csv|spec_markdown]
---

# E2Eテスト実行スキル

テスト仕様書とサービスURLを受け取り、Chrome in Claudeでブラウザ操作を行い、テスト結果をMarkdownレポートとして出力する。

> コードの変更は行わない。テスト実行と結果レポートのみを担当する。

---

## 引数の受け取り

このスキルは以下の引数を期待する:

- **テスト仕様書** *(省略可)*: CSVまたはMarkdownファイルのパス（例: `/path/to/test_spec.csv`）
- **サービスURL**: テスト対象のURL（例: `https://example.com`）

URLが省略された場合は既存のブラウザタブから推測する。

---

## ステップ0: テスト仕様書の準備（省略時のみ）

テスト仕様書が指定されていない場合は、`test-spec-generator` サブエージェントを呼び出してテスト仕様書を自動生成する。差分解析とテスト仕様書生成をサブエージェントに委譲することで、大量の差分データがメインコンテキストを圧迫するのを防ぐ。

```
Agent ツールで subagent_type: "test-spec-generator" を起動する:
  prompt: "カレントブランチと production ブランチの差分を解析し、
           E2Eテストに使用するテスト仕様書をMarkdown形式で生成してください。
           テスト対象URL: {指定されたURL（あれば）}"
```

サブエージェントが返したMarkdown形式のテスト仕様書をステップ1以降のインプットとして使用する。ユーザーにも生成内容を表示してから進む。

---

## ステップ1: テスト仕様書の解析

`Read` ツールでファイルを読み込み、以下の構造に変換する:

```
{
  title: string,           // テストタイトル（あれば）
  target_url: string,      // テスト対象URL（引数から取得）
  sections: [
    {
      name: string,        // セクション名
      cases: [
        {
          no: number | string,
          category: string,
          test_item: string,
          procedure: string,   // 操作手順（改行区切り）
          expected: string,    // 期待結果（改行区切り）
          notes: string
        }
      ]
    }
  ]
}
```

**CSV形式の場合**: `■` で始まる行をセクション区切りとして扱う。セル内の改行はステップ区切りとして使用する。

**Markdown形式の場合**: `##` や `###` 見出しをセクション、テーブルや箇条書きをテストケースとして解析する。

---

## ステップ2: ブラウザの準備

`mcp__claude-in-chrome__tabs_context_mcp` でタブ一覧を取得する。

- 引数で指定されたURLが既存タブにある場合はそのタブを使用する
- ない場合は `mcp__claude-in-chrome__tabs_create_mcp` で新規タブを作成し、指定URLにアクセスする

---

## ステップ3: テストケースの実行

各ケースを1件ずつ実行し、結果を記録してから次に進む。セクション開始時にユーザーへ進捗を報告する（例: `■ ログイン機能（5件）の実行を開始します`）。

### 操作ツールの選択

| 操作内容 | 使用ツール |
| --- | --- |
| 画面遷移 | `mcp__claude-in-chrome__navigate` |
| クリック | `mcp__claude-in-chrome__find` → `ref_id` で操作 |
| フォーム入力 | `mcp__claude-in-chrome__form_input` |
| テキスト確認 | `mcp__claude-in-chrome__get_page_text` |
| 要素状態確認 | `mcp__claude-in-chrome__javascript_tool` |
| ページ構造確認 | `mcp__claude-in-chrome__read_page` |

操作前後で状態を取得することで、変化を確実に捉える。

### 期待結果の検証

| 期待結果の種類 | 検証方法 |
| --- | --- |
| テキスト表示 | `get_page_text` で文字列を確認 |
| 要素の表示/非表示 | `javascript_tool` で `offsetParent` や `display` を確認 |
| disabled状態 | `javascript_tool` で `element.disabled` を確認 |
| トースト通知 | 操作直後すぐに `get_page_text` でキャプチャ（数秒で消えるため） |
| スタイル確認 | `javascript_tool` で `getComputedStyle()` を確認 |

### 判定基準

| 判定 | 条件 |
| --- | --- |
| ✅ PASS | 全ての期待結果が確認できた |
| ❌ FAIL | 1つ以上の期待結果が確認できなかった |
| ⚠️ SKIP | 前提条件が整わず実行できなかった（理由を記録） |
| 🔄 PARTIAL | 一部の期待結果は確認できたが一部は未確認 |

---

## ステップ4: 注意事項

**トースト通知**: 数秒で消えるため、操作直後に即座にキャプチャする。見逃した場合は操作を再実行して再確認する。

**権限が必要なケース**: 現在のログインユーザーで対応できない場合はSKIPとして理由を記録する。

**SPAのルーター遷移**: `javascript_tool` で `.click()` 後に `window.location.href` を確認する。

---

## ステップ5: レポート出力

全件実行後、以下のフォーマットでMarkdownレポートをチャットに出力する（ファイル保存不要）。

```markdown
# E2Eテスト実行レポート

**テスト仕様書**: {ファイル名}
**テスト対象URL**: {URL}
**実行日時**: {YYYY-MM-DD HH:mm}

---

## サマリー

| 結果 | 件数 |
| --- | --- |
| ✅ PASS | {n} |
| ❌ FAIL | {n} |
| ⚠️ SKIP | {n} |
| 🔄 PARTIAL | {n} |
| **合計** | **{total}** |

---

## セクション別結果

### {セクション名}

| No | テスト項目 | 結果 | 詳細 |
| --- | --- | --- | --- |
| 1 | {テスト項目} | ✅ PASS | {確認内容} |
| 2 | {テスト項目} | ❌ FAIL | {失敗理由} |

---

## 失敗・スキップ詳細

### No.{n}: {テスト項目}

- **結果**: ❌ FAIL / ⚠️ SKIP
- **期待結果**: {期待結果}
- **実際の動作**: {実際の動作}
- **備考**: {備考欄の内容}
```
