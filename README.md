# macos-app-scaffold

[中文](README_CN.md) | [日本語](README_JA.md) | [Deutsch](README_DE.md)

AI agent skill for scaffolding and enhancing production-ready macOS apps. Works with Claude Code, Cursor, Codex, Gemini, and 40+ other agents.

Extracted from real-world patterns across multiple shipped macOS apps using XcodeGen, GitHub Actions, SwiftUI, and Apple notarization.

## What It Can Do

All features are interactive — you pick what you need, skip what you don't.

**Project Setup**
- Create a new macOS app from scratch (Menu Bar / Windowed / Hybrid)
- XcodeGen (`project.yml`) as single source of truth
- Runnable SwiftUI starter code that compiles out of the box
- Git init with proper `.gitignore`
- `AGENTS.md` + `CLAUDE.md` symlink for multi-agent workflows

**Build & Distribution**
- GitHub Actions CI/CD (build, sign, notarize, DMG, release)
- Universal binary (arm64 + x86_64)
- Code signing & Apple notarization (optional — works without Apple Developer Account too)
- Auto-create GitHub Release on `v*` tags
- Release notes in multiple languages (English, Chinese, Japanese, German, etc.)
- Homebrew Cask formula

**App Features**
- Auto-update (GitHub API polling or Sparkle)
- Launch at Login (`SMAppService`)
- Accessibility permission gate
- Settings / Preferences window
- File-based logging (`~/Library/Logs/<AppName>.log`)
- Localization (multi-language)
- Analytics (Aptabase, privacy-respecting)
- Onboarding / Welcome window

**Code Quality**
- SwiftLint config with sensible defaults
- Unit test target (XCTest)
- App Sandbox toggle (with App Store trade-off explanation)

**License & Docs**
- LICENSE file (MIT / GPL-3.0 / Apache-2.0)
- README.md with badges (build status, macOS version, license)

## Quick Start

```
/macos-app-scaffold
```

That's it. The skill auto-detects whether you're in an existing project or starting fresh, and routes you to the right workflow.

You can also be explicit:

```
/macos-app-scaffold new MyApp              # Create a new app
/macos-app-scaffold enhance                # Add features to current project
```

## Skills

### `/macos-app-scaffold` — Entry point (auto-routes)

Detects your context and asks:
- **Existing project found** → offer to add features (CI/CD, auto-update, logging, etc.)
- **No project found** → walk through new app creation wizard

### `/macos-app-scaffold-new` — Create a new project

Interactive wizard that walks you through app name, archetype, features, and CI/CD options, then generates everything.

```
/macos-app-scaffold-new MyApp me.xueshi.myapp
```

### `/macos-app-scaffold-enhance` — Add features to an existing project

Analyzes your current project, shows what's already in place, and lets you surgically add missing features:

```
/macos-app-scaffold-enhance                  # Full analysis + pick features
/macos-app-scaffold-enhance ci-cd            # Add CI/CD directly
/macos-app-scaffold-enhance auto-update      # Add auto-update directly
/macos-app-scaffold-enhance logging          # Add file-based logging
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
/macos-app-scaffold              # Entry point (auto-routes)
/macos-app-scaffold-new          # Create new
/macos-app-scaffold-enhance      # Enhance existing
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
