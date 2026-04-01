---
name: macos-app-scaffold-new
description: Scaffold a new macOS app with XcodeGen, GitHub Actions CI/CD, code signing, notarization, auto-update, and SwiftUI starter code
argument-hint: "[AppName] [BundleID]"
disable-model-invocation: true
allowed-tools: Bash, Write, Read, Edit, Glob, Grep, Agent
---

# New macOS App Scaffold

Create a production-ready macOS application project. Walk the user through interactive choices, then generate all files.

## Arguments

- `$ARGUMENTS[0]` = App name (e.g., `MyApp`)
- `$ARGUMENTS[1]` = Bundle ID (e.g., `me.xueshi.myapp`)

If arguments are missing, ask the user before proceeding.

---

## Interactive Flow

Ask questions in this exact order. Present each step clearly with numbered/lettered options and defaults in **bold**. Wait for user response before proceeding to the next step. You may combine steps 3 and 4 into a single message if appropriate, presenting them as a checklist.

### Step 1: Identity (from args or ask)

- **App Name** (required) — used for directory name, target name, display name
- **Bundle ID** (required, suggest default: `me.xueshi.<appname-lowercase>`)

### Step 2: App Archetype

Ask user to pick one:
- **A) Menu Bar only** — `LSUIElement: true`, NSStatusItem, no dock icon
- **B) Windowed only** — standard WindowGroup, dock icon visible
- **C) Menu Bar + Window** — hybrid: menu bar extra + main window

Default: **A**

### Step 3: Features

Present as a checklist. User can accept defaults or customize:

| Feature | Default | Notes |
|---------|---------|-------|
| Runnable starter app | **Yes** | Generates compilable Swift source files |
| XcodeGen (`project.yml`) | **Yes** | Single source of truth for build config |
| App Sandbox | **No** | Required for App Store. Incompatible with Accessibility API, CGEvent tap, etc. Tell the user this trade-off. |
| SPM dependencies | **Yes** | Ask which: GRDB, KeyboardShortcuts, Sparkle, etc. |
| SwiftLint config | **No** | Generates `.swiftlint.yml` with sensible defaults |
| Unit test target | **Yes** | XCTest skeleton with one example test |
| Launch at Login | **Yes** if menu bar archetype, **No** otherwise | Uses `SMAppService` |
| Accessibility permission gate | **No** | Startup permission check + prompt (for apps using CGEvent tap, AXUIElement, etc.) |
| Localization | **No** | If yes, ask which languages (always includes English). Generates `Localizable.xcstrings` or `.strings`. |
| File-based logging | **Yes** | `~/Library/Logs/<AppName>.log` with lightweight FileLog class |
| Settings/Preferences window | **Yes** | SwiftUI `Settings` scene scaffold |
| Analytics (Aptabase) | **No** | Privacy-respecting event tracking |
| Onboarding/Welcome window | **No** | First-launch experience window |

### Step 4: CI/CD & Distribution

| Feature | Default | Condition | Notes |
|---------|---------|-----------|-------|
| Apple Developer Account | **Yes** | — | If NO: skip code signing, notarization, and stapling in CI. Build unsigned only. |
| GitHub Actions CI/CD | **Yes** | — | Build pipeline. If no Apple account, builds unsigned universal binary only. |
| Auto release on `v*` tags | **Yes** | Requires CI/CD | `softprops/action-gh-release@v2` |
| Release notes languages | **English** | Requires auto release | User can add more: Chinese, Japanese, German, etc. |
| Auto-update mechanism | **None** | Requires CI/CD + Apple account | A) GitHub API polling (lightweight) B) Sparkle (full-featured, requires SPM dep) C) None |
| Homebrew Cask formula | **No** | Requires CI/CD | Template `.rb` file for `brew install --cask` |
| License | **MIT** | — | MIT / GPL-3.0 / Apache-2.0 / None |
| README.md | **Yes** | — | With badges (build status, macOS version, license), install instructions, screenshots section |

### Step 5: Always Generated (no choice, do not ask)

These are always created regardless of choices:
- `git init` + `.gitignore`
- `AGENTS.md` (project conventions) + `CLAUDE.md` symlink → `AGENTS.md`
- Entitlements file (content varies based on sandbox choice)

---

## Generation Rules

After collecting all answers, generate files in the project directory (current working directory + `/<AppName>/`).

### Generation Order

1. Create directory structure
2. `git init`
3. `.gitignore`
4. `project.yml` (if XcodeGen)
5. Entitlements file
6. `Info.plist` (if needed)
7. Swift source files (if runnable starter)
8. `.swiftlint.yml` (if selected)
9. `Assets.xcassets` structure
10. `.github/workflows/build.yml` (if CI/CD)
11. Homebrew Cask formula (if selected)
12. `LICENSE`
13. `README.md` (if selected)
14. `AGENTS.md` + `CLAUDE.md` symlink
15. Initial git commit

### After Generation

Print a summary:
1. List all generated files
2. Show next steps:
   - `cd <AppName>`
   - `brew install xcodegen && xcodegen generate` (if XcodeGen)
   - `open <AppName>.xcodeproj` then Cmd+R
   - List GitHub secrets to configure (if CI/CD + Apple account)
   - Remind to push with `git push -u origin main && git push --tags`

---

## File Templates

### .gitignore

```
# Xcode
build/
DerivedData/
*.xcuserdata
xcuserdata/

# XcodeGen generated project
*.xcodeproj/

# Generated Info.plist (managed by XcodeGen)
# Uncomment if using GENERATE_INFOPLIST_FILE: YES
# **/Info.plist

# Swift Package Manager
.build/
Packages/
Package.resolved

# macOS
.DS_Store
.AppleDouble
.LSOverride

# Misc
*.swp
*~
```

If NOT using XcodeGen, remove the `*.xcodeproj/` line.

### project.yml (XcodeGen)

```yaml
name: {{AppName}}
options:
  bundleIdPrefix: {{BundleIDPrefix}}
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "16.0"
  minimumXcodeGenVersion: "2.35"

settings:
  base:
    SWIFT_VERSION: "6.0"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    ARCHS: "$(ARCHS_STANDARD)"
    ONLY_ACTIVE_ARCH_Release: "NO"
    ENABLE_HARDENED_RUNTIME: YES
    CODE_SIGN_STYLE: Automatic
    DEVELOPMENT_TEAM: ""
    SWIFT_STRICT_CONCURRENCY: targeted

# If SPM dependencies selected, add:
# packages:
#   PackageName:
#     url: https://github.com/...
#     majorVersion: X.Y.Z

targets:
  {{AppName}}:
    type: application
    platform: macOS
    sources:
      - path: {{AppName}}/Sources
      - path: {{AppName}}/Assets.xcassets
      # If localization: add Resources path
    info:
      path: {{AppName}}/Info.plist
      properties:
        LSUIElement: {{true if menu bar, false if windowed}}
        CFBundleDisplayName: $(PRODUCT_NAME)
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        # If accessibility gate:
        # NSAppleEventsUsageDescription: "..."
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: {{BundleID}}
        CODE_SIGN_ENTITLEMENTS: {{AppName}}/Resources/{{AppName}}.entitlements
        PRODUCT_NAME: {{AppName}}
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: "1"
        COMBINE_HIDPI_IMAGES: true
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    entitlements:
      path: {{AppName}}/Resources/{{AppName}}.entitlements
    # If SPM deps:
    # dependencies:
    #   - package: PackageName

  # If unit test target:
  # {{AppName}}Tests:
  #   type: bundle.unit-test
  #   platform: macOS
  #   sources:
  #     - path: {{AppName}}Tests
  #   dependencies:
  #     - target: {{AppName}}
  #   settings:
  #     base:
  #       BUNDLE_LOADER: $(TEST_HOST)
  #       TEST_HOST: $(BUILT_PRODUCTS_DIR)/{{AppName}}.app/Contents/MacOS/{{AppName}}
```

Adapt the template based on user choices. Remove comments, fill in actual values.

### Entitlements

**Without sandbox:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
```

**With sandbox:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

### Swift Source Files (if runnable starter)

Generate these based on archetype. All files go in `{{AppName}}/Sources/`.

#### App Entry Point: `{{AppName}}App.swift`

**Menu Bar only:**
```swift
import SwiftUI

@main
struct {{AppName}}App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("{{AppName}}", systemImage: "app.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
```

**Windowed only:**
```swift
import SwiftUI

@main
struct {{AppName}}App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        Settings {
            SettingsView()
        }
    }
}
```

**Menu Bar + Window (hybrid):**
```swift
import SwiftUI

@main
struct {{AppName}}App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        MenuBarExtra("{{AppName}}", systemImage: "app.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
```

#### AppDelegate.swift

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App startup logic here
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup logic here
    }
}
```

If Launch at Login is enabled, add `import ServiceManagement` and SMAppService setup.
If Analytics is enabled, add Aptabase initialization.
If Accessibility gate is enabled, add permission check call.

#### ContentView.swift (if windowed or hybrid)

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "app.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Welcome to {{AppName}}")
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}
```

#### MenuBarView.swift (if menu bar archetype)

```swift
import SwiftUI

struct MenuBarView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("{{AppName}}")
                .font(.headline)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 240)
    }
}
```

#### SettingsView.swift (if settings window)

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    // If Launch at Login:
    // @State private var launchAtLogin = false

    var body: some View {
        Form {
            Text("Settings go here")
            // If Launch at Login:
            // Toggle("Launch at Login", isOn: $launchAtLogin)
            //     .onChange(of: launchAtLogin) { _, newValue in
            //         LaunchAtLoginManager.shared.setEnabled(newValue)
            //     }
        }
        .padding()
    }
}
```

#### LaunchAtLoginManager.swift (if Launch at Login)

```swift
import ServiceManagement

final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }
}
```

#### PermissionManager.swift (if Accessibility gate)

```swift
import AppKit
import ApplicationServices

final class PermissionManager {
    static let shared = PermissionManager()

    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func ensureAccessibility(completion: @escaping () -> Void) {
        if isAccessibilityGranted {
            completion()
            return
        }

        requestAccessibilityIfNeeded()

        // Poll until granted
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
}
```

#### FileLog.swift (if file-based logging)

```swift
import Foundation

final class FileLog: Sendable {
    private let label: String
    private let fileURL: URL

    init(_ label: String) {
        self.label = label
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs")
        // Replace {{AppName}} with actual app name at generation time
        self.fileURL = logsDir.appendingPathComponent("{{AppName}}.log")
    }

    func info(_ message: String) {
        log("INFO", message)
    }

    func error(_ message: String) {
        log("ERROR", message)
    }

    private func log(_ level: String, _ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) [\(level)] [\(label)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
        #if DEBUG
        print("[\(label)] \(message)")
        #endif
    }
}
```

#### UpdateChecker.swift (if auto-update via GitHub API polling)

```swift
import Foundation

final class UpdateChecker: ObservableObject {
    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var downloadURL: URL?

    // Replace with actual GitHub owner/repo at generation time
    private let owner = "{{GitHubOwner}}"
    private let repo = "{{GitHubRepo}}"
    private let currentVersion: String

    init() {
        self.currentVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.0.0"
    }

    func checkForUpdates() async {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latest = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))

            await MainActor.run {
                self.latestVersion = latest
                self.updateAvailable = latest.compare(currentVersion, options: .numeric) == .orderedDescending
                self.downloadURL = release.assets.first(where: { $0.name.hasSuffix(".dmg") })?.browserDownloadURL
            }
        } catch {
            print("Update check failed: \(error)")
        }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let assets: [Asset]

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}
```

If auto-update is Sparkle instead, add `Sparkle` to SPM deps and generate `SPUStandardUpdaterController` setup instead of the above.

### Unit Test (if selected)

File: `{{AppName}}Tests/{{AppName}}Tests.swift`

```swift
import XCTest
@testable import {{AppName}}

final class {{AppName}}Tests: XCTestCase {
    func testExample() throws {
        XCTAssertTrue(true, "Project builds and tests run")
    }
}
```

### .swiftlint.yml (if selected)

```yaml
disabled_rules:
  - trailing_whitespace
  - line_length
  - type_body_length
  - file_length
  - function_body_length

opt_in_rules:
  - empty_count
  - closure_spacing
  - force_unwrapping
  - implicitly_unwrapped_optional

excluded:
  - DerivedData
  - build
  - .build
  - Packages
```

### GitHub Actions: `.github/workflows/build.yml`

Generate based on CI/CD choices. The workflow has conditional blocks.

```yaml
name: Build & Release

on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
    branches: [main]
  workflow_dispatch:

# Needed for creating releases
permissions:
  contents: write

env:
  APP_NAME: {{AppName}}
  SCHEME: {{AppName}}
  # Set to "true" if Apple secrets are configured
  HAS_APPLE_SECRETS: ${{"{{"}} secrets.MAC_CERTS_P12_BASE64 != '' {{"}}"}}

jobs:
  build:
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v4

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '16.1'

      - name: Install tools
        run: |
          brew install xcodegen create-dmg

      - name: Generate Xcode project
        run: xcodegen generate

      - name: Build universal binary
        run: |
          xcodebuild -project $APP_NAME.xcodeproj \
            -scheme $SCHEME \
            -configuration Release \
            ARCHS="arm64 x86_64" \
            ONLY_ACTIVE_ARCH=NO \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            build \
            SYMROOT=$(pwd)/build

      # ---- Apple Developer Account required below ----
      # If user has no Apple account, these steps are skipped via HAS_APPLE_SECRETS

      - name: Import signing certificate
        if: env.HAS_APPLE_SECRETS == 'true'
        env:
          P12_BASE64: ${{"{{"}} secrets.MAC_CERTS_P12_BASE64 {{"}}"}}
          P12_PASSWORD: ${{"{{"}} secrets.MAC_CERTS_P12_PASSWORD {{"}}"}}
        run: |
          echo "$P12_BASE64" | base64 --decode > certificate.p12
          KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
          KEYCHAIN_PASSWORD=$(uuidgen)
          security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security import certificate.p12 -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
          security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security list-keychain -d user -s "$KEYCHAIN_PATH"
          rm certificate.p12

      - name: Sign app
        if: env.HAS_APPLE_SECRETS == 'true'
        run: |
          codesign --force --options runtime \
            --sign "Developer ID Application" \
            --timestamp \
            --entitlements {{AppName}}/Resources/{{AppName}}.entitlements \
            build/Release/$APP_NAME.app

      - name: Create DMG
        run: |
          create-dmg \
            --volname "$APP_NAME" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "$APP_NAME.app" 150 190 \
            --hide-extension "$APP_NAME.app" \
            --app-drop-link 450 190 \
            "$APP_NAME.dmg" \
            "build/Release/$APP_NAME.app" || true
          # create-dmg exits 2 on "DMG created but icon layout failed" which is OK

      - name: Sign DMG
        if: env.HAS_APPLE_SECRETS == 'true'
        run: |
          codesign --force --sign "Developer ID Application" --timestamp "$APP_NAME.dmg"

      - name: Notarize DMG
        if: env.HAS_APPLE_SECRETS == 'true'
        env:
          APPLE_ID: ${{"{{"}} secrets.APPLE_ID {{"}}"}}
          TEAM_ID: ${{"{{"}} secrets.APPLE_TEAM_ID {{"}}"}}
          APP_PASSWORD: ${{"{{"}} secrets.APP_SPECIFIC_PASSWORD {{"}}"}}
        run: |
          xcrun notarytool submit "$APP_NAME.dmg" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --password "$APP_PASSWORD" \
            --wait

      - name: Staple notarization ticket
        if: env.HAS_APPLE_SECRETS == 'true'
        run: |
          xcrun stapler staple "$APP_NAME.dmg"

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{"{{"}} env.APP_NAME {{"}}"}}-dmg
          path: ${{"{{"}} env.APP_NAME {{"}}"}}.dmg

      # ---- Release (tag-triggered only) ----

      - name: Create GitHub Release
        if: startsWith(github.ref, 'refs/tags/v')
        uses: softprops/action-gh-release@v2
        with:
          files: ${{"{{"}} env.APP_NAME {{"}}"}}.dmg
          generate_release_notes: true
          # If multiple languages for release notes, the body can be templated
          # body_path: RELEASE_NOTES.md
```

If the user does NOT have an Apple Developer Account, remove all steps that have `if: env.HAS_APPLE_SECRETS == 'true'` and the `HAS_APPLE_SECRETS` env var. Keep only: checkout, setup, build, create DMG (unsigned), upload artifact, and release.

If Homebrew Cask is selected, add a step that updates the cask formula file.

### Release Notes Languages

If multiple languages are selected, create a `RELEASE_TEMPLATE.md` at project root:

```markdown
## What's New / Release Notes

### English
- 

### {{Language2}} (e.g., Chinese / 中文)
- 
```

And add to `AGENTS.md` a convention:
> Release notes must include sections for each configured language: {{list of languages}}.

### Homebrew Cask (if selected)

File: `Casks/{{appname-lowercase}}.rb`

```ruby
cask "{{appname-lowercase}}" do
  version "1.0.0"
  sha256 ""

  url "https://github.com/{{GitHubOwner}}/{{GitHubRepo}}/releases/download/v#{version}/{{AppName}}.dmg"
  name "{{AppName}}"
  homepage "https://github.com/{{GitHubOwner}}/{{GitHubRepo}}"

  app "{{AppName}}.app"

  zap trash: [
    "~/Library/Preferences/{{BundleID}}.plist",
    "~/Library/Application Support/{{AppName}}",
    "~/Library/Logs/{{AppName}}.log",
  ]
end
```

### LICENSE

Generate the selected license file with the current year and "{{AppName}}" as the project name.

### README.md (if selected)

```markdown
# {{AppName}}

> Brief description here

[![Build](https://github.com/{{GitHubOwner}}/{{GitHubRepo}}/actions/workflows/build.yml/badge.svg)](https://github.com/{{GitHubOwner}}/{{GitHubRepo}}/actions/workflows/build.yml)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Features

- Feature 1
- Feature 2

## Screenshots

<!-- Add screenshots here -->

## Installation

### Download

Download the latest `.dmg` from [Releases](https://github.com/{{GitHubOwner}}/{{GitHubRepo}}/releases).

### Homebrew (if cask is generated)

```bash
brew install --cask {{appname-lowercase}}
```

## Build from Source

```bash
brew install xcodegen
xcodegen generate
open {{AppName}}.xcodeproj
# Cmd+R to build and run
```

## License

[MIT](LICENSE)
```

Adapt badges based on license choice and macOS version.

### AGENTS.md

Generate project-specific conventions. Always include:

```markdown
# Agent Guidelines for {{AppName}}

## Single Source of Truth
`project.yml` is the ONLY source of truth for project configuration. Do NOT edit
`.pbxproj` or `Info.plist` directly. Modify `project.yml` and run `xcodegen generate`.

## Build & Run
```bash
brew install xcodegen
cd {{project-root-if-nested}}
xcodegen generate
open {{AppName}}.xcodeproj  # Cmd+R to run
```

## Tech Stack
- Swift 6.0, SwiftUI, macOS 14.0+
- XcodeGen (`project.yml`)
- {{List selected SPM dependencies}}
- {{Archetype description}}

## Architecture
- Entry point: `{{AppName}}/Sources/{{AppName}}App.swift`
- {{List key files based on what was generated}}

## Versioning
- `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`
- Git tags (`v*`) trigger release builds

## CI/CD
{{If CI/CD: describe the pipeline}}
{{If Apple account: list required GitHub secrets}}

### GitHub Secrets Required
{{If Apple account:}}
- `MAC_CERTS_P12_BASE64` — Base64-encoded Developer ID Application certificate (.p12)
- `MAC_CERTS_P12_PASSWORD` — Password for the .p12 file
- `APPLE_ID` — Apple ID email for notarization
- `APPLE_TEAM_ID` — Apple Developer Team ID
- `APP_SPECIFIC_PASSWORD` — App-specific password for notarization

## Release Notes
{{If multiple languages: list language convention}}
```

Then create the `CLAUDE.md` symlink:
```bash
ln -s AGENTS.md CLAUDE.md
```

### Assets.xcassets

Create the minimal structure:

```
{{AppName}}/Assets.xcassets/
├── Contents.json
└── AppIcon.appiconset/
    └── Contents.json
```

`Assets.xcassets/Contents.json`:
```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

`AppIcon.appiconset/Contents.json`:
```json
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

### Analytics (if Aptabase selected)

Add to `project.yml` packages:
```yaml
Aptabase:
  url: https://github.com/nicklama/aptabase-swift
  majorVersion: 0.3.0
```

Add initialization in `AppDelegate.applicationDidFinishLaunching`:
```swift
import Aptabase

Aptabase.shared.initialize(appKey: "YOUR_APTABASE_KEY")
```

### Onboarding Window (if selected)

File: `{{AppName}}/Sources/WelcomeView.swift`

```swift
import SwiftUI

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "app.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Welcome to {{AppName}}")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Brief description of what the app does.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Get Started") {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .frame(width: 480, height: 360)
    }
}
```

Add to AppDelegate: check `UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")` and show welcome window if false.

### Localization (if selected)

If using `Localizable.xcstrings` (modern Xcode 15+ format), create the file with base language entries. Add each selected language to the `project.yml` settings:

```yaml
settings:
  base:
    LOCALIZATION_PREFERS_STRING_CATALOGS: YES
```

Add `Resources` to the sources list in `project.yml`:
```yaml
sources:
  - path: {{AppName}}/Sources
  - path: {{AppName}}/Assets.xcassets
  - path: {{AppName}}/Resources
```

Create `{{AppName}}/Resources/Localizable.xcstrings` with base entries for any UI strings in the generated files.

---

## Reminders

- All `{{placeholders}}` must be replaced with actual values from user input
- Do NOT generate an Xcode project file — XcodeGen handles that
- Ensure all generated Swift files compile together (no missing imports, no type errors)
- Use `@MainActor` and `Sendable` where appropriate for Swift 6.0 concurrency
- The `.xcodeproj` directory must be in `.gitignore` when using XcodeGen
- Always create `CLAUDE.md` as a symlink to `AGENTS.md`, never as a standalone file
