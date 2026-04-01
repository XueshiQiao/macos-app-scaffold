# macos-app-scaffold

[English](README.md) | [中文](README_CN.md) | [Deutsch](README_DE.md)

本番レベルの macOS アプリを作成・拡張するための Claude Code プラグイン。

XcodeGen、GitHub Actions、SwiftUI、Apple 公証を使用した、実際にリリース済みの複数の macOS アプリから抽出されたパターンです。

## クイックスタート

```
/macos-app
```

これだけです。Skill が既存プロジェクトの有無を自動検出し、適切なワークフローに誘導します。

明示的に指定することもできます：

```
/macos-app new MyApp              # 新しいアプリを作成
/macos-app enhance                # 既存プロジェクトに機能を追加
```

## Skills

### `/macos-app` — エントリーポイント（自動ルーティング）

コンテキストを検出して質問します：
- **既存プロジェクトを検出** → 機能追加を提案（CI/CD、自動更新、ログなど）
- **プロジェクトなし** → 新規アプリ作成ウィザードを開始

### `/new-macos-app` — 新規プロジェクト作成

完全な macOS アプリプロジェクトを生成するインタラクティブウィザード：

- **アプリタイプ**：メニューバー、ウィンドウ、またはハイブリッド
- **XcodeGen**（`project.yml`）を唯一の設定ソースとして使用
- **GitHub Actions CI/CD**：ビルド、署名、公証、DMG、リリース
- **ユニバーサルバイナリ**：arm64 + x86_64
- **自動更新**：GitHub API ポーリング または Sparkle
- **SwiftUI スターターコード**：選択したタイプに基づくコンパイル可能なアプリ
- **その他**：SwiftLint、ユニットテスト、ログイン時起動、アクセシビリティ権限、ローカライズ、ファイルログ、設定ウィンドウ、アナリティクス、オンボーディング、Homebrew Cask、LICENSE、README

```
/new-macos-app MyApp me.xueshi.myapp
```

### `/enhance-macos-app` — 既存プロジェクトに機能を追加

現在のプロジェクトを分析し、既存の機能を表示し、不足している機能を選択して追加できます：

```
/enhance-macos-app                  # 完全分析 + 機能選択
/enhance-macos-app ci-cd            # CI/CD を直接追加
/enhance-macos-app auto-update      # 自動更新を直接追加
/enhance-macos-app logging          # ファイルログを直接追加
```

## インストール

### ユニバーサル（Claude Code、Cursor、Codex、Gemini など 40 以上のエージェントに対応）

```bash
npx skills add XueshiQiao/macos-app-scaffold
```

### Claude Code のみ

```
/plugin install github:XueshiQiao/macos-app-scaffold
```

### 手動インストール

```bash
git clone https://github.com/XueshiQiao/macos-app-scaffold.git
cp -r macos-app-scaffold/skills/* ~/.claude/skills/
```

インストール後、以下のコマンドで利用できます：

```
/macos-app              # エントリーポイント（自動ルーティング）
/new-macos-app          # 新規作成
/enhance-macos-app      # 既存プロジェクト拡張
```

## 生成されるファイル構造

```
MyApp/
├── .git/
├── .gitignore
├── project.yml                    # XcodeGen 設定（唯一の設定ソース）
├── MyApp/
│   ├── Sources/
│   │   ├── MyAppApp.swift         # @main エントリーポイント
│   │   ├── ContentView.swift      # メインウィンドウ（ウィンドウモード）
│   │   ├── MenuBarView.swift      # メニューバー UI（メニューバーモード）
│   │   ├── SettingsView.swift     # 環境設定ウィンドウ
│   │   ├── AppDelegate.swift      # アプリライフサイクル
│   │   ├── FileLog.swift          # ログユーティリティ
│   │   └── ...                    # その他の選択した機能
│   ├── Resources/
│   │   └── MyApp.entitlements
│   └── Assets.xcassets/
├── .github/workflows/
│   └── build.yml                  # CI/CD パイプライン
├── AGENTS.md                      # AI Agent 規約
├── CLAUDE.md → AGENTS.md          # シンボリックリンク
├── LICENSE
└── README.md
```

## CI/CD パイプライン

生成される GitHub Actions ワークフローは以下をサポートします：

- ユニバーサルバイナリのビルド（arm64 + x86_64）
- Developer ID 証明書による署名（オプション — Apple 開発者アカウントなしでも動作）
- ドラッグ＆ドロップインストール対応の DMG 作成
- Apple 公証（オプション）
- 公証チケットのステープル（オプション）
- `v*` タグプッシュ時に GitHub Release を自動作成

### 必要な GitHub Secrets（Apple 開発者アカウントがある場合）

| Secret | 説明 |
|--------|------|
| `MAC_CERTS_P12_BASE64` | Base64 エンコードされた Developer ID Application 証明書 |
| `MAC_CERTS_P12_PASSWORD` | .p12 ファイルのパスワード |
| `APPLE_ID` | 公証用の Apple ID メールアドレス |
| `APPLE_TEAM_ID` | Apple 開発者チーム ID |
| `APP_SPECIFIC_PASSWORD` | 公証用の App 専用パスワード |

Apple 開発者アカウントがない場合、パイプラインは未署名の DMG をビルドします — 配布には問題なく使用できます。

## デフォルト設定

| 設定項目 | デフォルト値 |
|----------|-------------|
| Swift | 6.0 |
| macOS | 14.0+ |
| UI | SwiftUI |
| サンドボックス | なし（ユーザー選択） |
| アーキテクチャ | Universal（arm64 + x86_64） |
| ビルドシステム | XcodeGen |

## ライセンス

MIT
