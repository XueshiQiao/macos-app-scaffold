# macos-app-scaffold

[中文](README_CN.md) | [日本語](README_JA.md) | [Deutsch](README_DE.md)

Claude Code plugin for scaffolding and enhancing production-ready macOS apps.

Extracted from real-world patterns across multiple shipped macOS apps using XcodeGen, GitHub Actions, SwiftUI, and Apple notarization.

## Quick Start

```
/macos-app
```

That's it. The skill auto-detects whether you're in an existing project or starting fresh, and routes you to the right workflow.

You can also be explicit:

```
/macos-app new MyApp              # Create a new app
/macos-app enhance                # Add features to current project
```

## Skills

### `/macos-app` — Entry point (auto-routes)

Detects your context and asks:
- **Existing project found** → offer to add features (CI/CD, auto-update, logging, etc.)
- **No project found** → walk through new app creation wizard

### `/new-macos-app` — Create a new project

Interactive wizard that generates a complete macOS app project:

- **App archetypes**: Menu bar, Windowed, or Hybrid
- **XcodeGen** (`project.yml`) as single source of truth
- **GitHub Actions CI/CD**: build, sign, notarize, DMG, release
- **Universal binary**: arm64 + x86_64
- **Auto-update**: GitHub API polling or Sparkle
- **SwiftUI starter code**: compilable app with the archetype you chose
- **And more**: SwiftLint, unit tests, Launch at Login, Accessibility permission gate, localization, file-based logging, Settings window, analytics, onboarding, Homebrew Cask, LICENSE, README

```
/new-macos-app MyApp me.xueshi.myapp
```

### `/enhance-macos-app` — Add features to an existing project

Analyzes your current project, shows what's already in place, and lets you surgically add missing features:

```
/enhance-macos-app                  # Full analysis + pick features
/enhance-macos-app ci-cd            # Add CI/CD directly
/enhance-macos-app auto-update      # Add auto-update directly
/enhance-macos-app logging          # Add file-based logging
```

## Install

### Universal (works with Claude Code, Cursor, Codex, Gemini, and 40+ agents)

```bash
npx skills add XueshiQiao/macos-app-scaffold
```

### Claude Code only

```
/plugin install github:XueshiQiao/macos-app-scaffold
```

### Manual

```bash
git clone https://github.com/XueshiQiao/macos-app-scaffold.git
cp -r macos-app-scaffold/skills/* ~/.claude/skills/
```

After installation, the skills are available as:

```
/macos-app              # Entry point (auto-routes)
/new-macos-app          # Create new
/enhance-macos-app      # Enhance existing
```

## What Gets Generated

```
MyApp/
├── .git/
├── .gitignore
├── project.yml                    # XcodeGen config (single source of truth)
├── MyApp/
│   ├── Sources/
│   │   ├── MyAppApp.swift         # @main entry point
│   │   ├── ContentView.swift      # Main window (if windowed)
│   │   ├── MenuBarView.swift      # Menu bar UI (if menu bar)
│   │   ├── SettingsView.swift     # Preferences window
│   │   ├── AppDelegate.swift      # App lifecycle
│   │   ├── FileLog.swift          # Logging utility
│   │   └── ...                    # Other selected features
│   ├── Resources/
│   │   └── MyApp.entitlements
│   └── Assets.xcassets/
├── .github/workflows/
│   └── build.yml                  # CI/CD pipeline
├── AGENTS.md                      # AI agent conventions
├── CLAUDE.md → AGENTS.md          # Symlink
├── LICENSE
└── README.md
```

## CI/CD Pipeline

The generated GitHub Actions workflow supports:

- Build universal binary (arm64 + x86_64)
- Code sign with Developer ID certificate (optional — works without Apple Developer Account too)
- Create DMG with drag-to-Applications layout
- Notarize with Apple (optional)
- Staple notarization ticket (optional)
- Auto-create GitHub Release on `v*` tags

### Required GitHub Secrets (if you have an Apple Developer Account)

| Secret | Description |
|--------|-------------|
| `MAC_CERTS_P12_BASE64` | Base64-encoded Developer ID Application certificate |
| `MAC_CERTS_P12_PASSWORD` | Password for the .p12 file |
| `APPLE_ID` | Apple ID email for notarization |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APP_SPECIFIC_PASSWORD` | App-specific password for notarization |

If you don't have an Apple Developer Account, the pipeline builds an unsigned DMG — still fully functional for distribution.

## Defaults

| Setting | Default |
|---------|---------|
| Swift | 6.0 |
| macOS | 14.0+ |
| UI | SwiftUI |
| Sandbox | No (user choice) |
| Architecture | Universal (arm64 + x86_64) |
| Build system | XcodeGen |

## License

MIT
