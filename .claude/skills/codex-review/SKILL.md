---
name: codex-review
description: Codex CLI（read-only）を用いて、レビュー→Claude Code修正→再レビュー（ok: true まで）を反復し収束させるレビューゲート。仕様書/SPEC/PRD/要件定義/設計、実装計画（PLANS.md等）の作成・更新直後、major step（>=5 files / 新規モジュール / 公開API / infra・config変更）完了後、および git commit / PR / merge / release 前に使用する。キーワード: Codexレビュー, codex review, レビューゲート.
---

# Codex反復レビュー

## フロー
規模判定 → Codex規模別レビュー → Claude Code修正 → 再レビュー（`ok: true`まで反復）

[規模判定] → small:  diff → [修正ループ]
           → medium: arch → diff → [修正ループ]
           → large:  arch → diff並列 → cross-check → [修正ループ]

- Codex: read-onlyでレビュー（監査役）
- Claude Code: 修正担当

## 規模判定

| 規模 | 基準 | 戦略 |
|-----|------|-----|
| small | <=3ファイル、<=100行 | diff |
| medium | 4-10ファイル、100-500行 | arch → diff |
| large | >10ファイル、>500行 | arch → diff並列 → cross-check |

## 修正ループ
ok: false の場合、max_iters回まで反復:
1. issues解析 → 修正計画
2. Claude Codeが修正（最小差分のみ）
3. テスト/リンタ実行
4. Codexに再レビュー依頼

## Codex実行
codex exec --sandbox read-only "<PROMPT>"

## Codex出力スキーマ (JSON)
```json
{
  "ok": true,
  "phase": "arch|diff|cross-check",
  "summary": "レビューの要約",
  "issues": [
    {
      "severity": "blocker|major|minor|nit",
      "file": "path/to/file",
      "line": 42,
      "message": "問題の説明",
      "suggestion": "修正案"
    }
  ],
  "notes_for_next_review": "次回レビューで注視すべき点",
  "claude_md_update": {
    "needed": true,
    "reason": "CLAUDE.md の更新が必要な理由",
    "sections": ["更新すべきセクション名"],
    "suggestion": "具体的な追記・修正案"
  }
}
```

## レビュープロンプト構成

### Phase: arch（アーキテクチャレビュー）
```
あなたはSwift/iOS/TCAの専門家レビュアーです。
以下の差分のアーキテクチャをレビューしてください。

重点観点:
- モジュール境界・依存方向の妥当性（SPMマルチモジュール構成）
- TCA設計（State/Action/Reducer の責務分離）
- CLAUDE.md に記載のコーディング規約との整合性
- プライバシー配慮（位置情報・ログ出力の最小化）
- CLAUDE.md の更新要否（下記「CLAUDE.md 更新チェック観点」を参照）

{review_focus}

出力はJSON形式で。
```

### Phase: diff（差分レビュー）
```
あなたはSwift/iOSの専門家レビュアーです。
以下の差分を行単位でレビューしてください。

重点観点:
- Swift API Design Guidelines 準拠
- guard による早期return、ネストの深さ
- Optional の安全な扱い（強制アンラップ禁止）
- セキュリティ（OWASP Top 10）
- 既存APIとの互換性
- CLAUDE.md の更新要否（下記「CLAUDE.md 更新チェック観点」を参照）

{review_focus}

出力はJSON形式で。
```

### Phase: cross-check（クロスチェック）
```
あなたはSwift/iOSの専門家レビュアーです。
arch レビューと diff レビューの結果を統合し、
矛盾や見落としがないか横断チェックしてください。

加えて、今回の変更により CLAUDE.md の更新が必要かを判定してください。
判定基準は「CLAUDE.md 更新チェック観点」セクションを参照。

arch結果: {arch_result}
diff結果: {diff_results}

出力はJSON形式で。claude_md_update フィールドを必ず含めること。
```

## CLAUDE.md 更新チェック観点

レビュー時、以下に該当する変更がある場合は `claude_md_update.needed: true` とし、具体的な追記・修正案を提示する。

| チェック項目 | 該当セクション例 |
|------------|---------------|
| 新規モジュール追加・モジュール構成の変更 | 5. モジュール境界 / ディレクトリ方針 |
| 新しい外部依存（SPMパッケージ）の追加・削除 | 5. モジュール境界 / ディレクトリ方針 |
| TCA / SwiftData / Firebase の導入・設計決定 | 4.2, 4.3, 該当セクション |
| ビルド・テスト・Lintコマンドの確立・変更 | 6. ビルド・テスト・Lint |
| 公開APIの設計方針変更 | 4.1 Swift Style |
| Git / PR 運用ルールの変更 | 7. Git / PR 運用 |
| セキュリティ・プライバシーに関する新方針 | 9. セキュリティ / プライバシー |
| コーディング規約の新ルール・例外追加 | 4. コーディング規約 |
| 新しいCI/CDパイプライン・スクリプトの追加 | 6. ビルド・テスト・Lint |
| リポジトリ固有の決定事項 | 10. メモ |

### 判定基準
- **needed: true** — 変更内容がCLAUDE.mdの記載と矛盾する、または記載されていない新しい方針・構成を導入している
- **needed: false** — 既存のCLAUDE.mdの範囲内で完結する変更

## パラメータ

| 引数 | 既定 | 説明 |
|-----|-----|-----|
| max_iters | 5 | 最大反復（上限5） |
| review_focus | - | 重点観点（追加指示） |
| diff_range | HEAD | 比較範囲（例: HEAD~3..HEAD） |
| parallelism | 3 | large時の並列度（上限5） |

## 完了条件
- Codexが `ok: true` を返す
- または max_iters 到達（未解決issueをレポートに記載）

## 最終レポート出力
```
## Codex Review Report
- Phase: {phase}
- Iterations: {count}/{max_iters}
- Result: {ok: true/false}
- Summary: {summary}
- Remaining Issues: {issues}
- Fix History: {fix_log}
- Advisory Notes: {notes}

### CLAUDE.md 更新
- 更新要否: {needed}
- 理由: {reason}
- 対象セクション: {sections}
- 提案内容: {suggestion}
```
