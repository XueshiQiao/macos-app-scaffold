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

### Step 0: Generation strategy — template repo vs from-scratch (ask first)

Ask the user:

> I can scaffold this two ways:
> **A) From the template repo** *(default, fastest, fewest tokens)* — clones `XueshiQiao/macos-app-starter` and applies a small rename + customization diff. Best when your needs match the template's flavor (Menu Bar + Window hybrid, Sparkle, signed CI, full i18n, MIT, no sandbox).
> **B) From scratch** — generates every file from the templates in this skill. Best when your archetype/feature mix is far from the template (e.g., Menu Bar only, no Sparkle, sandboxed, no localization).
>
> Which would you like? **(default A)**

If the user picks **A (template)**, follow "Generation Path A: Template Clone" below — most steps simplify to "delete the parts you don't need" and "rename".

If the user picks **B (from-scratch)**, follow the existing `Step 1` → `Step 5` flow and the `Generation Rules` section.

The template's exact flavor (so you can judge fit on the user's behalf):
- Archetype: Menu Bar + Window (hybrid)
- Sandbox: No
- SPM deps: Sparkle, KeyboardShortcuts, Aptabase
- Auto-update: Sparkle
- Background helper: None
- Languages: English + Simplified Chinese
- License: MIT
- Cask: Draft (template_only topology)
- CI/CD: Two-track signed/unsigned (workflow file is in the template repo)

If 5+ of these don't match what the user wants, recommend B.

### Step 1: Identity (from args or ask)

- **App Name** (required) — used for directory name, target name, display name
- **Bundle ID** (required, suggest default: `me.xueshi.<appname-lowercase>`)

### Step 2: App Archetype

Ask user to pick one:
- **A) Menu Bar only** — `LSUIElement: true`, NSStatusItem, no dock icon
- **B) Windowed only** — standard WindowGroup, dock icon visible
- **C) Menu Bar + Window** — hybrid: menu bar extra + main window

Default: **A**

### Step 2.5: Background Helper (advanced — default None)

Ask once. Most apps don't need a separate helper process; the default is **None**
and you should not push users toward the other options. Show this table when asking:

| Option | What you get | Runs as | Approval | When to pick it | Limits / cost |
|---|---|---|---|---|---|
| **A) None** *(default)* | Single-process app. | user | n/a | 90% of apps. Anything you can do inside the main app process. | none |
| **B) Login Item** (`SMAppService.mainApp`) | Main app auto-launches at login. | user | none | Menu bar tools, chat clients, quick-capture apps that the user wants opened automatically. | Adds zero capability — only convenience. |
| **C) User Agent** (`SMAppService.agent`) | Separate `LaunchAgent` helper binary; launchd starts it on demand once the user has logged in. App ↔ helper via XPC. | user | none | Persistent background work that doesn't need root: clipboard watcher, sync engine, global hotkey daemon, on-device AI worker. | Two-process complexity, must design XPC protocol, helper signed with same Team ID. |
| **D) Privileged Daemon** (`SMAppService.daemon`) | Separate `LaunchDaemon` helper binary; launchd starts it on demand at the system level (no login required). App ↔ helper via privileged XPC. | **root** | **user must approve in System Settings** | VPN / packet filter, system-wide network proxy, kext-adjacent ops, services that must run before any user logs in (set `RunAtLoad` for that case). | High MAS review bar, helper effectively unsandboxable, runtime XPC caller authorization is your responsibility (see `HelperMain.swift`), user-visible approval flow. |

**Default: A (None).** Confirm explicitly before generating C or D. If the user
picks D, ask one verification question: *"Which specific operation needs root?"* —
if they cannot name one, steer them to C.

If C is selected, copy `templates/agent/` files into the project (see "Background
Helper Templates" section below).
If D is selected, copy `templates/daemon/` files (and tell the user about the
System Settings approval step).

If A or B is selected, skip the helper templates entirely.

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
| Screen Recording permission flow | **No** | For apps using ScreenCaptureKit (`SCShareableContent`, `SCStream`). Generates `ScreenRecordingPermission.swift` + a 3-state modal (`ScreenRecordingPromptView.swift`) that handles the **mandatory relaunch on first grant**. NOT a substitute for the Accessibility gate — first-grant semantics differ. |
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
| Homebrew Cask formula | **No** | Requires CI/CD | Template `.rb` file for `brew install --cask`. If yes, ALSO ask the tap-topology question below. |
| License | **MIT** | — | MIT / GPL-3.0 / Apache-2.0 / None |

#### Step 4a: Cask publishing target (only if Homebrew Cask = Yes)

Modern Homebrew (5.x) refuses to install casks from arbitrary paths — they must
live in a tap. Asking up front avoids generating a cask file in a location
nobody can install from. Present these four options:

| Option | Where the `.rb` lives | Install command users will run | When to pick |
|---|---|---|---|
| **A) Existing shared tap** *(default if user has one)* | `<owner>/homebrew-tap/Casks/<name>.rb` (separate repo) | `brew install --cask <owner>/tap/<name>` | User already publishes other casks from one shared tap. Ask for `<owner>` and confirm the repo name. |
| **B) New per-app tap** | `<owner>/homebrew-<name>/Casks/<name>.rb` (new separate repo) | `brew install --cask <owner>/<name>/<name>` | First cask, no shared tap yet, prefer per-app isolation. The skill scaffolds the tap repo skeleton (README + `Casks/`), but the user must `gh repo create` it. |
| **C) Submit to homebrew/cask** | upstream `Homebrew/homebrew-cask` PR | `brew install --cask <name>` | App is signed, notarized, has public releases, and has a working `livecheck`. Skill writes the cask + a checklist; user opens the PR manually. Note: `brew audit --new` rules apply only here. |
| **D) Template only** | `Casks/<name>.rb` in the app repo (NOT installable as-is) | n/a | User wants to decide later. README will document this is a draft and not a working install. |

Default: **A** if the user names an existing tap, otherwise **B**.

Capture: `cask_topology` ∈ {shared_tap, per_app_tap, homebrew_cask, template_only},
`tap_owner` (for A/B), `tap_repo_name` (for A: usually `homebrew-tap`; for B: `homebrew-<name>`).

These values drive: where the `.rb` is written, the README install command,
the CI cask-bump step's target repo, and which validation commands appear in
the post-generation summary.
| README.md | **Yes** | — | With badges (build status, macOS version, license), install instructions, screenshots section |

### Step 5: Always Generated (no choice, do not ask)

These are always created regardless of choices:
- `git init` + `.gitignore`
- `AGENTS.md` (project conventions) + `CLAUDE.md` symlink → `AGENTS.md`
- Entitlements file (content varies based on sandbox choice)

---

## Generation Path A: Template Clone (default)

Use this when the user picked **A** in Step 0. This is dramatically cheaper in tokens because the template repo holds all the boilerplate.

### Path A: Steps

1. **Clone via GitHub template:**
   ```bash
   gh repo create <OwnerOrUser>/<NewRepoName> --template XueshiQiao/macos-app-starter --public --clone
   cd <NewRepoName>
   ```
   If the user wants the project locally without creating a GitHub repo yet, use `gh repo clone` + delete-remote pattern, or `git clone --depth=1` + `rm -rf .git && git init`.

2. **Rename**. Find-and-replace across the repo:
   - `MacOSAppStarter` → `<AppName>`
   - `dev.xueshi.macos-app-starter` → `<BundleID>`
   - `macosappstarter` (lowercase, in cask file) → `<appname-lowercase>`
   - `XueshiQiao` → user's GitHub owner (in README badges, AGENTS.md, cask file URL, and project.yml's `SUFeedURL`)
   - `macos-app-starter` → user's repo name (in `SUFeedURL` and any GitHub-Releases-asset URLs in workflow)
   - Update `LICENSE` copyright holder

   **About `SUFeedURL`**: the template ships with the raw GitHub URL pattern (`https://raw.githubusercontent.com/<owner>/<repo>/main/appcast.xml`). CI generates `appcast.xml` on every tagged release and commits it back to `main` with `[skip ci]`. This matches the production pattern in AnyDrag, PastePawX, HyperCapsLock. Do NOT swap to a github.io URL unless Pages is actually set up — that's the failure mode that broke the first version of this template.

   **Sparkle keypair MUST be regenerated.** The template ships with `SUPublicEDKey` matching a throwaway private key stored as the template repo's `SPARKLE_EDDSA_KEY` secret. Forks that don't regenerate are accepting updates signed by anyone who can read the template repo's secret history — bad. The README's "Setup before you ship" step covers the regeneration commands.

   **Aptabase key MUST be replaced.** The template ships with the maintainer's real Aptabase key (`A-US-3800930688`) so events flow to a known dashboard during template development. Forks that don't replace it will leak their users' app-launch events into the maintainer's project.

   Files to touch (all done with `Edit`):
   - `project.yml`
   - `Casks/macosappstarter.rb` (rename file too)
   - `LICENSE`
   - `README.md`
   - `AGENTS.md` (which CLAUDE.md symlinks to)
   - All Swift sources under `MacOSAppStarter/Sources/` (the `MacOSAppStarter` directory itself must also be renamed to `<AppName>/`)
   - `MacOSAppStarter/Resources/MacOSAppStarter.entitlements` (rename file)
   - `MacOSAppStarterTests/MacOSAppStarterTests.swift` (rename test class + dir)
   - `Localizable.xcstrings` and `InfoPlist.xcstrings` (only the literal app name strings)

3. **Apply user-chosen customizations.** For each thing the user opted *out* of, delete the corresponding files/sections:

   | If user said NO to | Delete / modify |
   |---|---|
   | Menu Bar archetype (windowed only) | `AppDelegate.swift` (status item code), shrink to plain `NSApplicationDelegate`. Set `LSUIElement: false` (already false in template). Remove menu bar popover code. |
   | Window archetype (menu bar only) | Remove main `WindowGroup` from `MacOSAppStarterApp.swift`. Set `LSUIElement: true`. Remove `ContentView.swift`. |
   | Sparkle | Remove SPM dep, `UpdateManager.swift`, Update tab in Settings, `Check for Updates…` menu command. |
   | KeyboardShortcuts | Remove SPM dep, hotkey registration in `AppDelegate`, Shortcuts tab in Settings. |
   | Aptabase | Remove SPM dep, `Analytics.swift`, analytics toggle in Settings. |
   | Onboarding | Remove `OnboardingView.swift` and the first-launch trigger in `AppDelegate`. |
   | Accessibility gate | Remove `AccessibilityChecker.swift` and references in `ContentView`/`OnboardingView`. |
   | Screen Recording permission | Remove `ScreenRecordingChecker.swift` (or `ScreenRecordingPermission.swift`) and any `SCShareableContent` / `SCStream` / `SCScreenshotManager` call sites. Drop the `import ScreenCaptureKit` line. |
   | File logging | Remove `FileLog.swift` and all call sites (replace with `os.Logger` only). |
   | Localization | Remove `Localizable.xcstrings`, `InfoPlist.xcstrings`, `LocalizationManager.swift`. Strip `String(localized:)` calls back to bare strings. Remove `knownRegions` from `project.yml`. |
   | Launch at Login | Remove `LaunchAtLoginManager.swift` and toggle in Settings. |
   | Settings window | Remove `SettingsView.swift` and `Settings { ... }` scene. |
   | SwiftLint | Delete `.swiftlint.yml`. |
   | Unit tests | Delete `MacOSAppStarterTests/` and remove from `project.yml`. |
   | Homebrew Cask | Delete `Casks/`. |
   | CI/CD | Delete `.github/workflows/build.yml`. |

   For things the user opted *in* to that aren't in the template (e.g. App Sandbox, Background Helper, GRDB), fall back to the templates in `## File Templates` below — generate just those pieces.

4. **Regenerate the Xcode project** — `xcodegen generate`. Then build to verify nothing was broken by the rename: `xcodebuild -scheme <AppName> -destination 'platform=macOS' build`.

5. **Sparkle keys, Aptabase key, Apple Developer secrets** — same as the from-scratch path. The template ships placeholders; tell the user which to replace.

6. **Re-init git** if the user wants a clean history: `rm -rf .git && git init && git add . && git commit -m "Initial commit (from macos-app-starter template)"`.

### When NOT to use Path A

If the user's choice mix differs significantly from the template (Step 0 lists the exact flavor), recommend Path B instead — the template-deletion overhead may exceed the cost of generating the matching set from scratch. Rough rule: if 5+ of the template's choices are wrong for the user, prefer Path B.

---

## Generation Path B: From Scratch

Use this when the user picked **B** in Step 0. The rest of this document — the existing `Generation Rules`, `File Templates`, and `Background Helper Templates` sections — describes Path B.

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
3. **Cask validation** (only if Homebrew Cask was generated):
   - `brew style ./Casks/<name>.rb` — style check
   - `brew audit --cask --online <tap-ref>` — full audit (online checks fetch
     URLs, run livecheck, validate sha256). The `<tap-ref>` is whatever the
     install command uses (e.g., `<owner>/tap/<name>` for shared tap).
   - For topology C only, also run `brew audit --cask --new --online <tap-ref>`.
     The `--new` flag enforces the homebrew/cask main rules (popularity,
     `verified:` placement, etc.) and should be ignored for personal taps —
     they don't apply there.
   - For topology A/B, after pushing the cask repo: `brew tap <owner>/<short>` then `brew install --cask <full-ref>` to verify end-to-end.

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

#### ScreenRecordingPermission.swift + ScreenRecordingPromptView.swift (if Screen Recording flow)

Use the templates in
`skills/macos-app-scaffold-new/templates/screen-recording/` —
`ScreenRecordingPermission.swift`, `ScreenRecordingPromptView.swift`, and a
`README.md` documenting the gotchas. Read the README before generating.

The single non-negotiable invariant the manager encodes: on first grant,
ScreenCaptureKit (`SCShareableContent`, `SCStream`, `SCScreenshotManager`)
will NOT start working in the same process. The user MUST quit and relaunch.
Do not write a flow that polls `SCShareableContent` after grant — it does
not work, and "polling longer" does not fix it.

The manager exposes three states — `notGranted`, `grantedPendingRelaunch`,
`granted` — which the prompt view maps to three branches: explain → "Open
Settings" → poll → "Relaunch Now". Wire `ScreenRecordingPromptView` as a
`.sheet(isPresented:)` from any feature entry point that needs screen
capture. Gate all ScreenCaptureKit calls on
`ScreenRecordingPermission.shared.isReadyForCapture` (the canonical
helper) — never on `status != .notGranted`, which lets
`.grantedPendingRelaunch` through and produces silent failures.

When generating, also add this to the project's debug config:

```yaml
# project.yml
configs:
  Debug: debug
settings:
  configs:
    Debug:
      CODE_SIGN_IDENTITY: "Apple Development"   # NOT "-" (ad-hoc)
      DEVELOPMENT_TEAM: <user's Team ID>
```

Reason: ad-hoc / changing-identity rebuilds wipe the TCC entry silently,
which is the dev-loop bug that costs everyone a day the first time.

Do NOT add `NSScreenRecordingUsageDescription` to Info.plist. It is not
consulted by this API.

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
          if [[ -z "$P12_BASE64" || -z "$P12_PASSWORD" ]]; then
            echo "::error::MAC_CERTS_P12_BASE64 and MAC_CERTS_P12_PASSWORD must both be set."
            exit 1
          fi

          CERT_PATH="$RUNNER_TEMP/signing-cert.p12"
          KEYCHAIN_PATH="$RUNNER_TEMP/app-signing.keychain-db"
          KEYCHAIN_PASSWORD=$(uuidgen)

          echo "$P12_BASE64" | base64 --decode > "$CERT_PATH"
          security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security import "$CERT_PATH" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
          security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security list-keychain -d user -s "$KEYCHAIN_PATH"
          rm -f "$CERT_PATH"

      - name: Code sign app
        if: env.HAS_APPLE_SECRETS == 'true'
        env:
          SIGNING_IDENTITY: ${{"{{"}} secrets.SIGNING_IDENTITY || 'Developer ID Application' {{"}}"}}
        run: |
          APP_PATH="build/Release/$APP_NAME.app"
          ENTITLEMENTS="{{AppName}}/Resources/{{AppName}}.entitlements"

          # Inside-out signing: sign embedded code deepest-first.
          # Apple discourages --deep as it doesn't guarantee correct order.
          if [ -d "$APP_PATH/Contents/Frameworks" ]; then
            # 1. Sign every Mach-O binary individually
            find "$APP_PATH/Contents/Frameworks" -type f | while read -r f; do
              if file "$f" | grep -q "Mach-O"; then
                codesign --force --options runtime --timestamp \
                  --sign "$SIGNING_IDENTITY" "$f"
              fi
            done

            # 2. Sign bundles inside-out: xpc -> app -> framework/dylib
            find "$APP_PATH/Contents/Frameworks" -name "*.xpc" -type d | while read -r b; do
              codesign --force --options runtime --timestamp \
                --sign "$SIGNING_IDENTITY" "$b"
            done
            find "$APP_PATH/Contents/Frameworks" -name "*.app" -type d | while read -r b; do
              codesign --force --options runtime --timestamp \
                --sign "$SIGNING_IDENTITY" "$b"
            done
            find "$APP_PATH/Contents/Frameworks" \( -name "*.framework" -o -name "*.dylib" \) | while read -r b; do
              codesign --force --options runtime --timestamp \
                --sign "$SIGNING_IDENTITY" "$b"
            done
          fi

          # Sign embedded background helper executables (SMAppService agents/daemons).
          # The helper sits at Contents/MacOS/<helper> and the launchd plist sits at
          # Contents/Library/Launch{Agents,Daemons}/<helper-bundle-id>.plist. We sign
          # any non-main Mach-O in Contents/MacOS, with the helper's own entitlements
          # if present.
          if [ -d "$APP_PATH/Contents/MacOS" ]; then
            MAIN_EXECUTABLE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" \
              "$APP_PATH/Contents/Info.plist") || {
                echo "::error::Could not read CFBundleExecutable from $APP_PATH/Contents/Info.plist"
                exit 1
            }
            for helper in "$APP_PATH/Contents/MacOS/"*; do
              [ -f "$helper" ] || continue
              base=$(basename "$helper")
              [ "$base" = "$MAIN_EXECUTABLE" ] && continue
              file "$helper" | grep -q "Mach-O" || continue

              helper_ent="{{AppName}}/Helper/${base}.entitlements"
              if [ -f "$helper_ent" ]; then
                codesign --force --options runtime --timestamp \
                  --entitlements "$helper_ent" \
                  --sign "$SIGNING_IDENTITY" "$helper"
              else
                codesign --force --options runtime --timestamp \
                  --sign "$SIGNING_IDENTITY" "$helper"
              fi
            done
          fi

          # Sign main app bundle with entitlements
          codesign --force --options runtime --timestamp \
            --entitlements "$ENTITLEMENTS" \
            --sign "$SIGNING_IDENTITY" "$APP_PATH"

          # Verify
          codesign --verify --deep --strict --verbose=2 "$APP_PATH"

      - name: Notarize app
        if: env.HAS_APPLE_SECRETS == 'true'
        env:
          APPLE_ID: ${{"{{"}} secrets.APPLE_ID {{"}}"}}
          TEAM_ID: ${{"{{"}} secrets.APPLE_TEAM_ID {{"}}"}}
          APP_PASSWORD: ${{"{{"}} secrets.APP_SPECIFIC_PASSWORD {{"}}"}}
        run: |
          if [[ -z "$APPLE_ID" || -z "$APP_PASSWORD" || -z "$TEAM_ID" ]]; then
            echo "::error::Missing notarization secrets (APPLE_ID, APP_SPECIFIC_PASSWORD, or APPLE_TEAM_ID)"
            exit 1
          fi

          ditto -c -k --keepParent "build/Release/$APP_NAME.app" "$RUNNER_TEMP/notarize.zip"

          SUBMISSION_OUT=$(xcrun notarytool submit "$RUNNER_TEMP/notarize.zip" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --password "$APP_PASSWORD" \
            --wait 2>&1) || true
          echo "$SUBMISSION_OUT"

          SUBMISSION_ID=$(echo "$SUBMISSION_OUT" | grep -m1 "^  id:" | awk '{print $NF}')
          STATUS=$(echo "$SUBMISSION_OUT" | grep "^  status:" | awk '{print $NF}')

          if [[ "$STATUS" != "Accepted" ]]; then
            echo "--- Notarization Log ---"
            if [[ -n "$SUBMISSION_ID" ]]; then
              xcrun notarytool log "$SUBMISSION_ID" \
                --apple-id "$APPLE_ID" --team-id "$TEAM_ID" \
                --password "$APP_PASSWORD" 2>&1 || true
            fi
            echo "::error::Notarization failed with status: $STATUS"
            exit 1
          fi

          xcrun stapler staple "build/Release/$APP_NAME.app"
          rm -f "$RUNNER_TEMP/notarize.zip"

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

If Homebrew Cask is selected, append the cask-bump step below. It runs only
on tag pushes, after the GitHub Release is created (so the DMG URL resolves
and `sha256` matches). Skip this entirely for `cask_topology = template_only`.

The step pushes directly to the tap repo. For `cask_topology`:
- **A (shared_tap)**: target repo is `{{tap_owner}}/{{tap_repo_name}}`, file path `Casks/{{appname-lowercase}}.rb`.
- **B (per_app_tap)**: target repo is `{{tap_owner}}/homebrew-{{appname-lowercase}}`, file path `Casks/{{appname-lowercase}}.rb`.
- **C (homebrew_cask)**: do NOT auto-push to `Homebrew/homebrew-cask` (PR-only flow). Instead, comment in the workflow: `# After release, run: brew bump-cask-pr {{appname-lowercase}} --version <new>` so the user opens a PR by hand.

Required GitHub secret: `HOMEBREW_TAP_TOKEN` — a fine-grained PAT with
`Contents: Read and write` scope on the tap repo only. Do NOT reuse `GITHUB_TOKEN`;
it's scoped to the current repo and cannot push to the tap.

```yaml
      - name: Update Homebrew cask in tap repo
        if: startsWith(github.ref, 'refs/tags/v') && env.HAS_APPLE_SECRETS == 'true'
        env:
          TAP_REPO: {{tap_owner}}/{{tap_repo_name}}        # e.g. XueshiQiao/homebrew-tap
          CASK_PATH: Casks/{{appname-lowercase}}.rb
          TAP_TOKEN: ${{"{{"}} secrets.HOMEBREW_TAP_TOKEN {{"}}"}}
        run: |
          set -euo pipefail
          if [[ -z "$TAP_TOKEN" ]]; then
            echo "::warning::HOMEBREW_TAP_TOKEN not set — skipping cask update."
            exit 0
          fi

          VERSION="${GITHUB_REF_NAME#v}"
          DMG_PATH="$APP_NAME.dmg"
          SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')

          WORK="$RUNNER_TEMP/tap"
          git clone --depth=1 "https://x-access-token:${TAP_TOKEN}@github.com/${TAP_REPO}.git" "$WORK"
          cd "$WORK"

          # Bump version + sha256. Use perl (not sed -i) for portable in-place edit.
          perl -i -pe 's/^(\s*version\s+)"[^"]*"/$1"'"$VERSION"'"/' "$CASK_PATH"
          perl -i -pe 's/^(\s*sha256\s+)"[^"]*"/$1"'"$SHA256"'"/' "$CASK_PATH"

          if git diff --quiet; then
            echo "Cask already up-to-date at $VERSION."
            exit 0
          fi

          git -c user.name="github-actions[bot]" \
              -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
              commit -am "Update {{appname-lowercase}} to $VERSION"
          git push origin HEAD:main
```

Notes for whoever maintains this:
- `perl -i` is used over `sed -i` because `sed -i` syntax differs between
  GNU and BSD/macOS. The runner is macOS, so this matters.
- The commit message format matches what `brew bump-cask-pr` produces, so
  anyone later switching to PR-flow gets consistent history.
- For topology B, the user must `gh repo create` the tap repo before the first
  tag push; otherwise the clone step fails. Document this in the post-generation
  summary's "Next steps".

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

**Where the file goes** depends on `cask_topology` from Step 4a:

| `cask_topology`  | Path the skill writes |
|---|---|
| `shared_tap` (A) | The skill canNOT write to a sibling repo on disk. Print the cask body and instruct: "Save this as `Casks/{{appname-lowercase}}.rb` in your `{{tap_owner}}/{{tap_repo_name}}` repo and push." |
| `per_app_tap` (B) | Scaffold a sibling repo skeleton at `../homebrew-{{appname-lowercase}}/` containing `Casks/{{appname-lowercase}}.rb`, a minimal `README.md`, and `.gitignore`. Tell the user to `cd ../homebrew-{{appname-lowercase}} && gh repo create {{tap_owner}}/homebrew-{{appname-lowercase}} --public --source=. --push`. |
| `homebrew_cask` (C) | Write to `Casks/{{appname-lowercase}}.rb` in the app repo as a working draft, plus a `HOMEBREW_CASK_PR_CHECKLIST.md` (see below). The user copies the cask into a `homebrew-cask` fork to open the PR. |
| `template_only` (D) | Write to `Casks/{{appname-lowercase}}.rb` in the app repo with a comment header marking it as a draft. README must reflect that this is not yet installable. |

**Template** (used in all four cases — the only difference is where it lands):

```ruby
cask "{{appname-lowercase}}" do
  version "1.0.0"
  sha256 ""

  url "https://github.com/{{GitHubOwner}}/{{GitHubRepo}}/releases/download/v#{version}/{{AppName}}.dmg"
  # Add `verified:` ONLY when url's host differs from homepage's host (current
  # audit rule). Both this template's url and homepage point at github.com, so
  # `verified:` here is unnecessary and will be flagged by `brew audit`. If you
  # later host the DMG on a different domain, add e.g.:
  #   verified: "github.com/{{GitHubOwner}}/{{GitHubRepo}}/"
  name "{{AppName}}"
  desc "{{one-line description, ≤80 chars, no trailing period, no app name}}"
  homepage "https://github.com/{{GitHubOwner}}/{{GitHubRepo}}"

  # --- livecheck block: emit ONE of the two variants below ---
  # If auto_update_mechanism == "sparkle": use the :sparkle variant. The url
  # MUST match SUFeedURL in Info.plist. The recommended pattern is to host
  # the appcast as a GitHub Release asset:
  #   https://github.com/<owner>/<repo>/releases/latest/download/appcast.xml
  # so this livecheck url and the SUFeedURL are identical. Do NOT swap to
  # a guessed github.io URL — Pages is not on by default, and users without
  # Pages set up will get 404s. If the user has set up Pages explicitly, then
  # use their actual hosted URL.
  # If auto_update_mechanism == "github" or "none": use the :github_latest variant.

  # Variant A — Sparkle:
  livecheck do
    url "{{appcast-feed-url-from-SUFeedURL-or-TODO}}"
    strategy :sparkle
  end

  # Variant B — GitHub releases:
  livecheck do
    url :url
    strategy :github_latest
  end

  # --- auto_updates: include ONLY when auto_update_mechanism != "none" ---
  # Tells brew not to fight with the app's self-update. Required for Sparkle
  # apps and for any app that polls GitHub Releases internally.
  auto_updates true

  # depends_on macos: comes from the deployment target (e.g. macOS 14 → :sonoma).
  # Map: 12→:monterey, 13→:ventura, 14→:sonoma, 15→:sequoia, 26→:tahoe.
  depends_on macos: ">= :{{deployment_target_codename}}"

  app "{{AppName}}.app"

  zap trash: [
    "~/Library/Preferences/{{BundleID}}.plist",
    "~/Library/Application Support/{{AppName}}",
    "~/Library/Caches/{{BundleID}}",
    "~/Library/HTTPStorages/{{BundleID}}",
    "~/Library/Saved Application State/{{BundleID}}.savedState",
    "~/Library/Logs/{{AppName}}.log",
  ]
end
```

**For topology B (`per_app_tap`)**, also create the sibling repo skeleton:

`../homebrew-{{appname-lowercase}}/README.md`:
```markdown
# {{tap_owner}}/homebrew-{{appname-lowercase}}

Homebrew tap for [{{AppName}}](https://github.com/{{GitHubOwner}}/{{GitHubRepo}}).

## Install

```bash
brew install --cask {{tap_owner}}/{{appname-lowercase}}/{{appname-lowercase}}
```
```

`../homebrew-{{appname-lowercase}}/.gitignore`:
```
.DS_Store
```

**For topology C (`homebrew_cask`)**, also create `HOMEBREW_CASK_PR_CHECKLIST.md` at project root listing: signed + notarized release present, livecheck verified with `brew livecheck --cask Casks/{{appname-lowercase}}.rb`, `brew audit --cask --online --new Casks/{{appname-lowercase}}.rb` clean, fork `Homebrew/homebrew-cask`, copy the file to `Casks/{{first-letter}}/{{appname-lowercase}}.rb` (note the alphabetized subdirectory), open PR titled `Add {{appname-lowercase}} <version>`.

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

Render the install command according to `cask_topology`:

- **A) shared_tap**: `brew install --cask {{tap_owner}}/tap/{{appname-lowercase}}`
  (assumes `tap_repo_name` = `homebrew-tap`; brew auto-prepends the
  `homebrew-` prefix from the second segment, so users type `tap`, not the full repo name)
- **B) per_app_tap**: `brew install --cask {{tap_owner}}/{{appname-lowercase}}/{{appname-lowercase}}`
- **C) homebrew_cask** (after PR is merged): `brew install --cask {{appname-lowercase}}`
- **D) template_only**: omit this section entirely, OR include it with a
  prominent note: `<!-- Cask template generated but not yet published. The bare
  command below requires homebrew/cask submission; see Casks/{{appname-lowercase}}.rb. -->`

```bash
brew install --cask {{rendered-from-topology}}
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

The modern stack (Xcode 15+) uses **String Catalogs** (`.xcstrings`). They auto-extract strings from `String(localized:)` calls at build time and provide a UI for translation. Prefer them over legacy `.strings`/`.stringsdict`.

**1. project.yml additions:**

```yaml
settings:
  base:
    LOCALIZATION_PREFERS_STRING_CATALOGS: YES
    DEVELOPMENT_LANGUAGE: en           # or whatever the base language is
    SWIFT_EMIT_LOC_STRINGS: YES        # auto-extract String(localized:) at build time

# All selected languages must appear in `knownRegions` so Xcode picks them up.
# These are BCP-47 codes: en, zh-Hans, zh-Hant, ja, ko, de, fr, es, pt-BR, ...
options:
  knownRegions:
    - en
    - {{Language2}}                    # e.g. zh-Hans
    - Base                             # required by Xcode for resource loading

sources:
  - path: {{AppName}}/Sources
  - path: {{AppName}}/Assets.xcassets
  - path: {{AppName}}/Resources
```

**2. `{{AppName}}/Resources/Localizable.xcstrings`** — one file with all UI strings. Skeleton:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "Settings" : {
      "extractionState" : "manual",
      "localizations" : {
        "en"      : { "stringUnit" : { "state" : "translated", "value" : "Settings" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "设置" } }
      }
    }
  },
  "version" : "1.0"
}
```

After the first build with `SWIFT_EMIT_LOC_STRINGS: YES`, Xcode auto-fills new strings from `String(localized:)` calls. The skill should seed the file with strings for every UI string in generated Swift files (Settings, Onboarding, menu items, etc.).

**3. `{{AppName}}/Resources/InfoPlist.xcstrings`** — separate catalog for plist values like `CFBundleDisplayName`, `CFBundleName`, menu bar status item title. Required when you want the app's display name to be localized:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "CFBundleDisplayName" : {
      "localizations" : {
        "en"      : { "stringUnit" : { "state" : "translated", "value" : "{{AppName}}" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "{{ChineseAppName}}" } }
      }
    }
  },
  "version" : "1.0"
}
```

In Info.plist (or via XcodeGen `infoPlist:`), set `CFBundleDisplayName` to `$(CFBundleDisplayName)` so it's resolved from the catalog.

**4. Swift usage:**

```swift
// Preferred — String Catalogs auto-extract these.
Text("Settings")                                    // SwiftUI: implicit localization
let title = String(localized: "Welcome")            // explicit
let n = String(localized: "\(count) items")         // interpolation works

// Avoid: NSLocalizedString (older API; still works but not auto-extracted as cleanly)
// Avoid: bare String literals shown in UI without going through String(localized:)
```

**5. Runtime language switch (optional but common UX).** macOS apps inherit system language by default; many users want an in-app language picker. Provide a helper:

```swift
// {{AppName}}/Sources/LocalizationManager.swift
import Foundation
import SwiftUI

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @AppStorage("app.language") var languageCode: String = "" {
        didSet { applyLanguage() }
    }

    private init() { applyLanguage() }

    private func applyLanguage() {
        // Empty string = follow system. Non-empty = override via AppleLanguages.
        if languageCode.isEmpty {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        }
        // Note: system-resolved Bundle.main strings only update on next launch.
        // For instant switching, observe `objectWillChange` and key SwiftUI views by `languageCode`.
        objectWillChange.send()
    }
}
```

Then key the root view by `localizationManager.languageCode` (`.id(...)` in SwiftUI) so the view tree rebuilds on switch — strings re-resolve through `String(localized:)`'s lookup chain.

**6. AGENTS.md convention** — add this so future code stays localizable:

> All UI strings must go through `String(localized:)` (or SwiftUI implicit `Text("...")`). Never use bare `String` literals for text shown to users. New strings appear automatically in `Localizable.xcstrings` after build; translate non-English entries before merging.

**7. Release notes** — when multiple languages are configured, the release notes template (see "Release Notes Languages" above) should have a section per language so changelog text matches what Sparkle (or the user) shows.

---

## Background Helper Templates

Only use this section if the user picked **C (User Agent)** or **D (Privileged
Daemon)** in Step 2.5. For A and B, skip entirely.

Templates live alongside this skill:

```
templates/
├── agent/    # SMAppService.agent — user-context helper (no approval required)
└── daemon/   # SMAppService.daemon — root helper (user approval required)
```

Each template directory contains:

| File | Purpose |
|---|---|
| `README.md` | Per-template explanation; read this first |
| `HelperProtocol.swift` | Shared XPC protocol — compiled into BOTH targets |
| `HelperMain.swift` | Helper executable entry point |
| `HelperManager.swift` | App-side controller (register/unregister + XPC client) |
| `LaunchAgent.plist` / `LaunchDaemon.plist` | launchd plist embedded in app bundle |
| `project.yml.snippet` | XcodeGen target + dependency wiring |
| `entitlements.snippet.xml` | Helper target entitlements |

### Generation steps (when helper is selected)

1. Read the appropriate template `README.md` first to understand the structure.
2. Copy the template files into the project, substituting placeholders:
   - `{{AppName}}` → user's app name
   - `{{AppBundleID}}` → user's bundle ID (e.g. `me.xueshi.myapp`)
   - `{{HelperBundleID}}` → `<AppBundleID>.helper` (e.g. `me.xueshi.myapp.helper`)
   - `{{HelperExecutableName}}` → `<AppName>Helper` (e.g. `MyAppHelper`)
   - `{{TeamID}}` → only for daemon; ask the user (`security find-identity -p codesigning`)
3. Suggested layout in the project:
   ```
   {{AppName}}/
   ├── Sources/                       (existing app code, includes HelperManager.swift)
   ├── Shared/
   │   └── HelperProtocol.swift       (compiled into BOTH targets)
   └── Helper/
       ├── HelperMain.swift
       ├── {{HelperExecutableName}}.entitlements
       └── Launch{Agents,Daemons}/
           └── {{HelperBundleID}}.plist
   ```
4. Append the `project.yml.snippet` blocks into the user's `project.yml`.
5. Place `HelperManager.swift` in `Sources/` so the app can call it.
6. After scaffolding, tell the user:
   - Run `xcodegen generate` and build once.
   - For agent: call `try HelperManager.shared.register()` from a Settings toggle. Done.
   - For daemon: call `try HelperManager.shared.register()`, then watch for
     `status == .requiresApproval` and surface a button that calls
     `HelperManager.shared.openSystemSettings()`.

### Codesign loop

The CI codesign step in `build.yml` already includes a sweep of
`Contents/MacOS/<helper>` that picks up `<helper>.entitlements` if present at
`{{AppName}}/Helper/<helper>.entitlements`. Verify the path matches.

### What NOT to do

- Don't generate the daemon template unless the user explicitly confirmed they
  need root for a specific named operation. Default to agent or to no helper.
- Don't merge `HelperProtocol.swift` into the app target only — the helper
  target must compile against the exact same source file, or the connection
  invalidates silently at runtime.
- Don't enable `KeepAlive` / `RunAtLoad` in the launchd plist unless the user
  asked for "always running". On-demand activation is the recommended pattern.

---

## Reminders

- All `{{placeholders}}` must be replaced with actual values from user input
- Do NOT generate an Xcode project file — XcodeGen handles that
- Ensure all generated Swift files compile together (no missing imports, no type errors)
- Use `@MainActor` and `Sendable` where appropriate for Swift 6.0 concurrency
- The `.xcodeproj` directory must be in `.gitignore` when using XcodeGen
- Always create `CLAUDE.md` as a symlink to `AGENTS.md`, never as a standalone file
