# macos-app-scaffold

[English](README.md) | [中文](README_CN.md) | [日本語](README_JA.md)

AI Agent Skill zum Erstellen und Erweitern produktionsreifer macOS-Apps. Funktioniert mit Claude Code, Cursor, Codex, Gemini und 40+ weiteren Agents.

Basierend auf realen Mustern aus mehreren veröffentlichten macOS-Apps mit XcodeGen, GitHub Actions, SwiftUI und Apple-Notarisierung.

## Unterstützte Funktionen

Alle Funktionen sind interaktiv — wähle, was du brauchst, überspringe den Rest.

**Projekt-Setup**
- Neue macOS-App von Grund auf erstellen (Menüleiste / Fenster / Hybrid)
- XcodeGen (`project.yml`) als einzige Konfigurationsquelle
- Sofort kompilierbarer SwiftUI Starter-Code
- Git-Initialisierung mit korrekter `.gitignore`
- `AGENTS.md` + `CLAUDE.md` Symlink für Multi-Agent-Workflows

**Build & Distribution**
- GitHub Actions CI/CD (Bauen, Signieren, Notarisieren, DMG, Release)
- Universal Binary (arm64 + x86_64)
- Code-Signierung & Apple-Notarisierung (optional — funktioniert auch ohne Apple-Entwicklerkonto)
- Automatisch GitHub Release bei `v*` Tags
- Mehrsprachige Release Notes (Englisch, Chinesisch, Japanisch, Deutsch usw.)
- Homebrew Cask Formel

**App-Funktionen**
- Auto-Update (GitHub API Polling oder Sparkle)
- Autostart (`SMAppService.mainApp`)
- Background Helper mit XPC (`SMAppService.agent` im Benutzerkontext oder `.daemon` privilegiert — siehe Tabelle unten)
- Barrierefreiheits-Berechtigungsgate
- Bildschirmaufnahme-Berechtigungsfluss (ScreenCaptureKit, mit Neustart-Handling beim ersten Erteilen)
- Einstellungen / Preferences Fenster
- Datei-basiertes Logging (`~/Library/Logs/<AppName>.log`)
- Lokalisierung (mehrsprachig)
- Analytics (Aptabase, datenschutzfreundlich)
- Onboarding / Willkommensfenster

### Background-Helper-Optionen

Die meisten Apps laufen als ein einziger Prozess. Diese vier Optionen sind
optionale Erweiterungen — **Standard ist None**. Wähle die kleinste Option,
die deinen Anforderungen genügt.

| Option | Was du bekommst | Läuft als | Benutzergenehmigung | Wann verwenden | Einschränkungen |
|---|---|---|---|---|---|
| **None** *(Standard)* | App mit einem Prozess | Benutzer | keine | Alles, was im Hauptprozess der App erledigt werden kann | keine |
| **Login Item** (`SMAppService.mainApp`) | Haupt-App startet automatisch beim Login | Benutzer | keine | Menüleisten-Tools, Chat-Clients, Quick-Capture-Apps, die automatisch geöffnet werden sollen | Bringt keine zusätzliche Fähigkeit — nur Komfort |
| **User Agent** (`SMAppService.agent`) | Separate Helper-Binary; launchd startet sie bei Bedarf, sobald der Benutzer angemeldet ist. App ↔ Helper über XPC | Benutzer | keine | Persistente Hintergrundarbeit ohne Root: Clipboard-Watcher, Sync-Engine, globale Hotkeys, On-Device-AI-Worker | Zwei-Prozess-Architektur, XPC-Protokoll erforderlich, Helper mit derselben Team-ID signiert |
| **Privileged Daemon** (`SMAppService.daemon`) | Separate Helper-Binary; launchd startet sie bei Bedarf auf Systemebene (keine Anmeldung erforderlich). App ↔ Helper über privilegiertes XPC | **root** | **erforderlich** (Systemeinstellungen → Anmeldeobjekte & Erweiterungen) | VPN / Paketfilter, systemweiter Proxy, Kext-nahe Operationen, Dienste, die vor jeder Benutzeranmeldung laufen müssen (in dem Fall `RunAtLoad` setzen) | Hohe MAS-Review-Hürde, Helper praktisch nicht sandboxbar, Laufzeit-XPC-Aufruferautorisierung liegt beim Helper selbst, sichtbarer Genehmigungsfluss |

Lauffähige Vorlagen für User Agent und Privileged Daemon — inklusive launchd
plist, XPC-Protokoll, App-seitigem Controller und `project.yml`-Konfiguration —
befinden sich unter
[`skills/macos-app-scaffold-new/templates/`](skills/macos-app-scaffold-new/templates/).

**Code-Qualität**
- SwiftLint Konfiguration (sinnvolle Standardregeln)
- Unit-Test Target (XCTest)
- App Sandbox Toggle (mit App Store Trade-off Erklärung)

**Lizenz & Dokumentation**
- LICENSE Datei (MIT / GPL-3.0 / Apache-2.0)
- README.md mit Badges (Build-Status, macOS-Version, Lizenz)

## Schnellstart

```
/macos-app-scaffold
```

Das ist alles. Der Skill erkennt automatisch, ob du dich in einem bestehenden Projekt befindest oder neu anfängst, und leitet dich zum passenden Workflow weiter.

Du kannst auch explizit angeben:

```
/macos-app-scaffold new MyApp              # Neue App erstellen
/macos-app-scaffold enhance                # Funktionen zum aktuellen Projekt hinzufügen
```

## Skills

###  `/macos-app-scaffold` — Einstiegspunkt (automatisches Routing)

Erkennt deinen Kontext und fragt:
- **Bestehendes Projekt erkannt** → bietet an, Funktionen hinzuzufügen (CI/CD, Auto-Update, Logging usw.)
- **Kein Projekt erkannt** → startet den Assistenten zur Erstellung einer neuen App

### `/macos-app-scaffold-new` — Neues Projekt erstellen

Interaktiver Assistent, der dich durch App-Name, Typ, Funktionen und CI/CD-Optionen führt und dann alles generiert.

```
/macos-app-scaffold-new MyApp me.xueshi.myapp
```

### `/macos-app-scaffold-enhance` — Funktionen zu bestehendem Projekt hinzufügen

Analysiert dein aktuelles Projekt, zeigt vorhandene Funktionen an und lässt dich fehlende gezielt hinzufügen:

```
/macos-app-scaffold-enhance                  # Vollständige Analyse + Funktionen wählen
/macos-app-scaffold-enhance ci-cd            # CI/CD direkt hinzufügen
/macos-app-scaffold-enhance auto-update      # Auto-Update direkt hinzufügen
/macos-app-scaffold-enhance logging          # Datei-Logging direkt hinzufügen
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
/macos-app-scaffold              # Einstiegspunkt (automatisches Routing)
/macos-app-scaffold-new          # Neu erstellen
/macos-app-scaffold-enhance      # Bestehendes erweitern
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
