# macos-app-scaffold

[English](README.md) | [中文](README_CN.md) | [日本語](README_JA.md)

Claude Code Plugin zum Erstellen und Erweitern produktionsreifer macOS-Apps.

Basierend auf realen Mustern aus mehreren veröffentlichten macOS-Apps mit XcodeGen, GitHub Actions, SwiftUI und Apple-Notarisierung.

## Schnellstart

```
/macos-app
```

Das ist alles. Der Skill erkennt automatisch, ob du dich in einem bestehenden Projekt befindest oder neu anfängst, und leitet dich zum passenden Workflow weiter.

Du kannst auch explizit angeben:

```
/macos-app new MyApp              # Neue App erstellen
/macos-app enhance                # Funktionen zum aktuellen Projekt hinzufügen
```

## Skills

### `/macos-app` — Einstiegspunkt (automatisches Routing)

Erkennt deinen Kontext und fragt:
- **Bestehendes Projekt erkannt** → bietet an, Funktionen hinzuzufügen (CI/CD, Auto-Update, Logging usw.)
- **Kein Projekt erkannt** → startet den Assistenten zur Erstellung einer neuen App

### `/new-macos-app` — Neues Projekt erstellen

Interaktiver Assistent, der ein vollständiges macOS-App-Projekt generiert:

- **App-Typen**: Menüleiste, Fenster oder Hybrid
- **XcodeGen** (`project.yml`) als einzige Konfigurationsquelle
- **GitHub Actions CI/CD**: Bauen, Signieren, Notarisieren, DMG, Release
- **Universal Binary**: arm64 + x86_64
- **Auto-Update**: GitHub API Polling oder Sparkle
- **SwiftUI Starter-Code**: kompilierbares App basierend auf dem gewählten Typ
- **Und mehr**: SwiftLint, Unit-Tests, Autostart, Barrierefreiheits-Berechtigung, Lokalisierung, Datei-Logging, Einstellungsfenster, Analytics, Onboarding, Homebrew Cask, LICENSE, README

```
/new-macos-app MyApp me.xueshi.myapp
```

### `/enhance-macos-app` — Funktionen zu bestehendem Projekt hinzufügen

Analysiert dein aktuelles Projekt, zeigt vorhandene Funktionen an und lässt dich fehlende gezielt hinzufügen:

```
/enhance-macos-app                  # Vollständige Analyse + Funktionen wählen
/enhance-macos-app ci-cd            # CI/CD direkt hinzufügen
/enhance-macos-app auto-update      # Auto-Update direkt hinzufügen
/enhance-macos-app logging          # Datei-Logging direkt hinzufügen
```

## Installation

### Universal (funktioniert mit Claude Code, Cursor, Codex, Gemini und 40+ Agents)

```bash
npx skills add XueshiQiao/macos-app-scaffold
```

### Nur Claude Code

```
/plugin install github:XueshiQiao/macos-app-scaffold
```

### Manuelle Installation

```bash
git clone https://github.com/XueshiQiao/macos-app-scaffold.git
cp -r macos-app-scaffold/skills/* ~/.claude/skills/
```

Nach der Installation sind die Skills verfügbar als:

```
/macos-app              # Einstiegspunkt (automatisches Routing)
/new-macos-app          # Neu erstellen
/enhance-macos-app      # Bestehendes erweitern
```

## Generierte Dateistruktur

```
MyApp/
├── .git/
├── .gitignore
├── project.yml                    # XcodeGen-Konfiguration (einzige Quelle)
├── MyApp/
│   ├── Sources/
│   │   ├── MyAppApp.swift         # @main Einstiegspunkt
│   │   ├── ContentView.swift      # Hauptfenster (Fenstermodus)
│   │   ├── MenuBarView.swift      # Menüleisten-UI (Menüleistenmodus)
│   │   ├── SettingsView.swift     # Einstellungsfenster
│   │   ├── AppDelegate.swift      # App-Lebenszyklus
│   │   ├── FileLog.swift          # Logging-Werkzeug
│   │   └── ...                    # Weitere ausgewählte Funktionen
│   ├── Resources/
│   │   └── MyApp.entitlements
│   └── Assets.xcassets/
├── .github/workflows/
│   └── build.yml                  # CI/CD Pipeline
├── AGENTS.md                      # AI-Agent-Konventionen
├── CLAUDE.md → AGENTS.md          # Symbolischer Link
├── LICENSE
└── README.md
```

## CI/CD Pipeline

Der generierte GitHub Actions Workflow unterstützt:

- Universal Binary bauen (arm64 + x86_64)
- Code-Signierung mit Developer ID Zertifikat (optional — funktioniert auch ohne Apple-Entwicklerkonto)
- DMG mit Drag-and-Drop-Installation erstellen
- Apple-Notarisierung (optional)
- Notarisierungsticket heften (optional)
- Automatisch GitHub Release bei `v*` Tags erstellen

### Erforderliche GitHub Secrets (mit Apple-Entwicklerkonto)

| Secret | Beschreibung |
|--------|-------------|
| `MAC_CERTS_P12_BASE64` | Base64-kodiertes Developer ID Application Zertifikat |
| `MAC_CERTS_P12_PASSWORD` | Passwort für die .p12 Datei |
| `APPLE_ID` | Apple ID E-Mail für die Notarisierung |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APP_SPECIFIC_PASSWORD` | App-spezifisches Passwort für die Notarisierung |

Ohne Apple-Entwicklerkonto baut die Pipeline ein unsigniertes DMG — weiterhin voll funktionsfähig zur Verteilung.

## Standardeinstellungen

| Einstellung | Standard |
|-------------|----------|
| Swift | 6.0 |
| macOS | 14.0+ |
| UI | SwiftUI |
| Sandbox | Nein (Benutzerauswahl) |
| Architektur | Universal (arm64 + x86_64) |
| Build-System | XcodeGen |

## Lizenz

MIT
