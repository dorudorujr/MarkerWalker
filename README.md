# MarkerWalker

歩き専門のナビアプリ

## 概要

MarkerWalkerは、案内地点の特徴を丁寧にわかりやすく説明し、ユーザーが覚えやすい案内を提供する徒歩ナビアプリです。

## 技術スタック

- **Swift 6** / **SwiftUI**
- **SPM (Swift Package Manager)** - マルチモジュール構成
- **async/await**
- **TCA (The Composable Architecture)** - 導入予定
- **Firebase** - 導入予定
- **SwiftData** - 導入予定

## プロジェクト構成

```
MarkerWalker/
├── App/                           # Xcodeプロジェクト
│   ├── iOS/
│   │   ├── Assets.xcassets
│   │   └── MarkerWalkerApp.swift
│   └── MarkerWalker.xcodeproj
├── MarkerWalker/                  # SPMパッケージ
│   ├── Package.swift
│   └── Sources/
│       ├── AppFeature/            # メインFeature
│       └── AppResources/          # ローカライズリソース
│           ├── Resources/
│           │   └── ja.lproj/
│           │       └── Localizable.strings
│           └── Generated/         # SwiftGen生成コード（.gitignore）
│               └── Strings.swift
├── Mintfile                       # 開発ツール管理
├── swiftgen.yml                   # SwiftGen設定
├── .swiftlint.yml                 # SwiftLint設定
└── .swift-format                  # swift-format設定
```

## セットアップ

### 1. 開発ツールのインストール

```bash
# Mintのインストール（Homebrewを使用）
brew install mint

# 依存ツールのインストール
mint bootstrap
```

### 2. パッケージの解決

Xcodeでプロジェクトを開き、パッケージを解決します:

1. `App/MarkerWalker.xcodeproj` を開く
2. **File > Packages > Reset Package Caches**
3. **File > Packages > Resolve Package Versions**

## ローカライズ管理（SwiftGen）

### 文言の追加方法

1. **ローカライズファイルに文言を追加**

   `MarkerWalker/Sources/AppResources/Resources/ja.lproj/Localizable.strings` を編集:

   ```
   /* ナビゲーション関連 */
   "navigation.start" = "案内を開始";
   "navigation.stop" = "案内を停止";

   /* 一般 */
   "app.title" = "MarkerWalker";
   ```

2. **SwiftGenでコード生成**

   ```bash
   mint run swiftgen config run --config swiftgen.yml
   ```

   これにより、`MarkerWalker/Sources/AppResources/Generated/Strings.swift` が生成されます。

3. **生成されたAPIを使用**

   ```swift
   import AppResources

   // 使用例
   Text(L10n.Navigation.start)  // "案内を開始"
   Text(L10n.Navigation.stop)   // "案内を停止"
   Text(L10n.App.title)         // "MarkerWalker"
   ```

### Xcode Build Phaseでの自動生成（推奨）

ビルド時に自動でコードを生成するには:

1. Xcodeで `MarkerWalker` ターゲットを選択
2. **Build Phases** タブを開く
3. `+` → **New Run Script Phase**
4. 以下のスクリプトを追加:

   ```bash
   export PATH="$PATH:/opt/homebrew/bin"
   if which mint >/dev/null; then
     cd "$SRCROOT/.."
     mint run swiftgen config run --config swiftgen.yml
   else
     echo "warning: Mint not installed, run 'brew install mint'"
   fi
   ```

5. **Input Files** に追加:
   ```
   $(SRCROOT)/../swiftgen.yml
   $(SRCROOT)/../MarkerWalker/Sources/AppResources/Resources/ja.lproj/Localizable.strings
   ```

6. **Output Files** に追加:
   ```
   $(SRCROOT)/../MarkerWalker/Sources/AppResources/Generated/Strings.swift
   ```

7. このPhaseを "Compile Sources" の前に移動

## コード品質管理

### SwiftLint

```bash
# 手動でLintを実行
mint run swiftlint lint

# 自動修正
mint run swiftlint lint --fix
```

### swift-format

```bash
# 手動でフォーマット
mint run swift-format format --in-place --recursive .
```

## ビルド

```bash
# コマンドラインからビルド
cd MarkerWalker
swift build

# Xcodeでビルド
# App/MarkerWalker.xcodeproj を開いてCmd+B
```

## コーディング規約

詳細は `CLAUDE.md` を参照してください。

### 主要な規約

- **Swift 6** 準拠
- `guard` で早期return、ネストを浅く
- Optional は安全に扱い、強制アンラップは原則禁止
- 命名は Swift API Design Guidelines 準拠

## ドキュメント

- **CLAUDE.md** - Claude Code（AI）向けのプロジェクトガイド
  - プロジェクト概要、コーディング規約、Git運用など

## ライセンス

TBD

## 貢献

TBD
