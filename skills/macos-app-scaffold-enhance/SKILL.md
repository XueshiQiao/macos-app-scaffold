---
name: macos-app-scaffold-enhance
description: Add features to an existing macOS app — CI/CD, auto-update, logging, SwiftLint, localization, Launch at Login, and more
argument-hint: "[feature-name]"
disable-model-invocation: true
allowed-tools: Bash, Write, Read, Edit, Glob, Grep, Agent
---

# Enhance Existing macOS App

Add production-ready features to an existing macOS project. This skill analyzes the current project, shows what's already in place, and surgically adds only the new pieces.

Companion to `/new-macos-app` (which scaffolds from scratch).

## Arguments

- `$ARGUMENTS` = Optional feature name to add directly (e.g., `ci-cd`, `auto-update`, `logging`)

If no argument given, run the full analysis and let the user pick.

---

## Step 1: Analyze Existing Project

Before asking anything, scan the current directory for:

```
Check for:
├── project.yml              → XcodeGen?
├── *.xcodeproj/             → Xcode project exists?
├── Package.swift            → SPM package?
├── .github/workflows/*.yml  → CI/CD?
├── .swiftlint.yml           → SwiftLint?
├── .gitignore               → Git initialized?
├── AGENTS.md / CLAUDE.md    → Agent config?
├── LICENSE                  → License file?
├── README.md                → README?
├── Casks/*.rb               → Homebrew Cask?
├── **/Sources/**App.swift   → App entry point?
├── **/*.entitlements        → Entitlements?
├── **/Info.plist            → App metadata?
└── **/*.xcstrings or *.strings → Localization?
```

Also read `project.yml` (or `.pbxproj` info) to determine:
- App name, bundle ID, deployment target
- Current SPM dependencies
- Sandbox status
- Whether it's a menu bar app (LSUIElement)
- Current version numbers

## Step 2: Show Status Dashboard

Present a clear dashboard of what exists vs what can be added:

```
## Project: {{AppName}} ({{BundleID}})

### Already in place
 ✓ XcodeGen (project.yml)
 ✓ Git initialized
 ✓ GitHub Actions CI/CD
 ✓ Entitlements (no sandbox)

### Available to add
 1. Auto-update mechanism (GitHub API polling / Sparkle)
 2. File-based logging
 3. SwiftLint config
 4. Unit test target
 5. Launch at Login
 6. Accessibility permission gate
 7. Screen Recording permission flow
 8. Localization
 9. Settings/Preferences window
 10. Analytics (Aptabase)
 11. Onboarding/Welcome window
 12. Homebrew Cask formula
 13. README.md with badges
 14. License file
 15. AGENTS.md + CLAUDE.md symlink

Which features would you like to add? (comma-separated numbers, or "all")
```

Only show features that are NOT already detected. If a feature partially exists, note it (e.g., "CI/CD exists but missing notarization steps").

If the user provided an argument (e.g., `/enhance-macos-app auto-update`), skip the dashboard and go directly to that feature.

## Step 3: Add Selected Features

For each selected feature, follow these rules:

### General Rules

1. **Read before writing.** Always read existing files before modifying them. Never overwrite existing code.
2. **Surgical additions.** Add new files, append to existing configs. Don't restructure what's already there.
3. **Respect existing patterns.** If the project uses tabs, use tabs. If it has a specific import style, match it.
4. **XcodeGen awareness.** If `project.yml` exists, modify it instead of the Xcode project. Remind the user to run `xcodegen generate` after.
5. **No breaking changes.** New features must not break existing builds.
6. **Explain what changed.** After each feature, list exactly what files were created/modified.

### Feature: CI/CD (GitHub Actions)

**Adds:** `.github/workflows/build.yml`

Before generating, ask:
- Do you have an Apple Developer Account? (affects signing/notarization steps)
- What Xcode version? (default: 16.1)

Generate the workflow from the template in `/new-macos-app` skill, adapted to the existing project:
- Read `project.yml` or project settings for app name, scheme name, entitlements path
- Use existing bundle ID and version info
- If no Apple account: unsigned build + DMG only
- If Apple account: full pipeline (sign → notarize → staple)

Also check if `.gitignore` needs updating for build artifacts.

### Feature: Auto-Update

**Prerequisite:** CI/CD must exist (check `.github/workflows/`). If not, offer to add CI/CD first.

Ask: Which approach?
- A) **GitHub API polling** (lightweight) — adds `UpdateChecker.swift`
- B) **Sparkle** (full-featured) — adds Sparkle SPM dependency + `SPUStandardUpdaterController` setup

For GitHub API polling:
- Ask for GitHub owner/repo (or detect from `git remote`)
- Generate `UpdateChecker.swift` (see new-macos-app templates)
- Show how to integrate in SettingsView or AppDelegate

For Sparkle:
- Add `Sparkle` (v2.9.0+) to `project.yml` packages section
- Add `SUFeedURL` to Info.plist properties in `project.yml`
- Generate `SPUStandardUpdaterController` setup in AppDelegate
- Add "Check for Updates" menu item or Settings toggle

**EdDSA key generation** — instruct the user to run locally:
```bash
# Download Sparkle, extract, then:
./bin/generate_keys
# This prints the public key (add to Info.plist as SUPublicEDKey)
# and saves the private key to Keychain.
# Export the private key and add as GitHub secret: SPARKLE_EDDSA_KEY
```

**CI/CD appcast generation** — add these steps to the existing `build.yml`:
```yaml
- name: Download Sparkle tools
  if: env.HAS_APPLE_SECRETS == 'true'
  run: |
    SPARKLE_VERSION="2.9.0"
    curl -sL -o "$RUNNER_TEMP/sparkle.tar.xz" \
      "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
    mkdir -p "$RUNNER_TEMP/sparkle"
    tar -xf "$RUNNER_TEMP/sparkle.tar.xz" -C "$RUNNER_TEMP/sparkle"

- name: Sign DMG and generate appcast
  if: env.HAS_APPLE_SECRETS == 'true'
  env:
    SPARKLE_EDDSA_KEY: ${{ secrets.SPARKLE_EDDSA_KEY }}
  run: |
    echo -n "$SPARKLE_EDDSA_KEY" > "$RUNNER_TEMP/sparkle_eddsa.key"
    SIGN_OUTPUT=$("$RUNNER_TEMP/sparkle/bin/sign_update" "$APP_NAME.dmg" -f "$RUNNER_TEMP/sparkle_eddsa.key")
    rm -f "$RUNNER_TEMP/sparkle_eddsa.key"

    ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
    # Anchor the grep so it matches the SETTING line (MARKETING_VERSION: "1.2.3")
    # and skips reference lines like CFBundleShortVersionString: $(MARKETING_VERSION).
    # Without the anchor, `head -1` may pick a reference line that has no quotes
    # and `awk -F'"' '{print $2}'` returns empty — silently producing an appcast
    # with empty <sparkle:version>/<sparkle:shortVersionString>.
    VERSION=$(grep -E '^\s*MARKETING_VERSION: ' project.yml | head -1 | awk -F'"' '{print $2}')
    BUILD=$(grep -E '^\s*CURRENT_PROJECT_VERSION: ' project.yml | head -1 | awk -F'"' '{print $2}')
    if [ -z "$VERSION" ] || [ -z "$BUILD" ]; then
      echo "ERROR: failed to parse MARKETING_VERSION or CURRENT_PROJECT_VERSION from project.yml"
      exit 1
    fi
    FILE_LENGTH=$(stat -f%z "$APP_NAME.dmg")
    TAG="${GITHUB_REF_NAME}"
    DOWNLOAD_URL="https://github.com/${GITHUB_REPOSITORY}/releases/download/${TAG}/${APP_NAME}.dmg"

    {
      echo '<?xml version="1.0" encoding="utf-8"?>'
      echo '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
      echo '  <channel>'
      echo "    <title>${APP_NAME} Updates</title>"
      echo '    <item>'
      echo "      <title>Version ${VERSION}</title>"
      echo "      <sparkle:version>${BUILD}</sparkle:version>"
      echo "      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>"
      echo "      <enclosure url=\"${DOWNLOAD_URL}\" length=\"${FILE_LENGTH}\" type=\"application/octet-stream\" sparkle:edSignature=\"${ED_SIGNATURE}\" />"
      echo '    </item>'
      echo '  </channel>'
      echo '</rss>'
    } > appcast.xml
```

**Additional GitHub secrets for Sparkle:**
- `SPARKLE_EDDSA_KEY` — EdDSA private key exported from `generate_keys`

**Appcast hosting:** Upload `appcast.xml` alongside the DMG in the GitHub Release, or host it separately (e.g., GitHub Pages, S3). Set `SUFeedURL` in Info.plist to point to the hosted appcast.

### Feature: File-Based Logging

**Adds:** `FileLog.swift` in the Sources directory.

- Detect the Sources directory path from project structure
- Generate `FileLog.swift` with the app name in the log path
- Show usage example: `private let log = FileLog("ClassName")`

### Feature: SwiftLint

**Adds:** `.swiftlint.yml` at project root.

Generate sensible defaults (see new-macos-app template). Ask if they want strict or relaxed rules.

### Feature: Unit Test Target

**Modifies:** `project.yml` (if XcodeGen) to add test target.
**Adds:** `{{AppName}}Tests/{{AppName}}Tests.swift`

- Read existing target name from project.yml
- Add test target with dependency on main target
- Generate skeleton test file

### Feature: Launch at Login

**Adds:** `LaunchAtLoginManager.swift`
**Modifies:** Existing SettingsView (if found) to add toggle.

- Uses `SMAppService` (macOS 13+)
- If SettingsView exists, offer to add the toggle there

### Feature: Background Helper (User Agent or Privileged Daemon)

> Advanced. Almost no app needs this. The Launch at Login feature above is the
> right answer for "I want my app to start at login". This feature is for
> apps that need a **separate helper process** running in the background.

**Decision table** (show this verbatim when the user asks for this feature):

| Option | What you get | Runs as | Approval | Pick when… |
|---|---|---|---|---|
| **User Agent** (`SMAppService.agent`) | Separate helper binary; launchd starts it on demand once the user has logged in. App ↔ helper via XPC. | user | none | Background work that does **not** need root: clipboard watcher, sync engine, hotkey daemon, on-device AI worker. |
| **Privileged Daemon** (`SMAppService.daemon`) | Separate helper binary; launchd starts it on demand at the system level (no login required). App ↔ helper via privileged XPC. | **root** | **user must approve in System Settings** | VPN, packet filter, kext-adjacent, system-wide proxy, services that must run before any user logs in (set `RunAtLoad` for that). |

Default: **User Agent.** Confirm explicitly before adding the daemon variant.
If the user picks daemon, ask one verification question: *"Which specific
operation needs root?"* — if they cannot name one, steer them to agent.

**Adds (User Agent):**
- `Shared/HelperProtocol.swift` (compiled into both targets)
- `Helper/HelperMain.swift`
- `Helper/LaunchAgents/<HelperBundleID>.plist`
- `Helper/<HelperExecutableName>.entitlements`
- `Sources/HelperManager.swift`

**Adds (Privileged Daemon):**
- Same five files but under `Helper/LaunchDaemons/`
- Plist contains `SMAuthorizedClients` with the app's designated requirement
- `HelperManager.swift` includes status polling and `openSystemSettings()`

**Modifies:**
- `project.yml` — adds a `tool`-type helper target, copies the plist into
  `Contents/Library/Launch{Agents,Daemons}/`, and lists the helper as a
  dependency of the main app with `copy.destination: executables`
- `.github/workflows/build.yml` — extends the codesign loop to sign
  `Contents/MacOS/<helper>` with `<helper>.entitlements` if present
- Optionally, the existing SettingsView — adds a toggle bound to
  `HelperManager.shared`

**Templates location.** The agent and daemon templates ship with the
companion `macos-app-scaffold-new` skill. From this skill's directory the
relative path is `../macos-app-scaffold-new/templates/{agent,daemon}/`; from
the repo root it is `skills/macos-app-scaffold-new/templates/{agent,daemon}/`.
If you cannot find them locally (e.g., user installed only one skill), fetch
from the upstream repo at
`https://github.com/XueshiQiao/macos-app-scaffold/tree/main/skills/macos-app-scaffold-new/templates`.
Read each template's `README.md` before copying.

**Placeholders to substitute:**
- `{{AppName}}`, `{{AppBundleID}}` — read from `project.yml`
- `{{HelperBundleID}}` — default `<AppBundleID>.helper`, ask to confirm
- `{{HelperExecutableName}}` — default `<AppName>Helper`, ask to confirm
- `{{TeamID}}` — daemon only; ask the user, or run
  `security find-identity -p codesigning -v` and offer the matches

**After generating, tell the user:**
1. Run `xcodegen generate` and build.
2. For agent: call `try HelperManager.shared.register()` from a Settings toggle. Helper launches on first XPC call.
3. For daemon: call `try HelperManager.shared.register()`. If `status` becomes `.requiresApproval`, surface a button that calls `HelperManager.shared.openSystemSettings()`. After the user flips the switch, `status` transitions to `.enabled`.
4. Test without rebooting:
   - Agent: `launchctl kickstart -k gui/$(id -u)/<HelperBundleID>`
   - Daemon: `sudo launchctl kickstart -k system/<HelperBundleID>`
   - Logs: `log stream --predicate 'subsystem == "<HelperBundleID>"'`

### Feature: Accessibility Permission Gate

**Adds:** `PermissionManager.swift`
**Modifies:** `AppDelegate.swift` to call permission check on launch.

- Read existing AppDelegate to find the right insertion point
- Add `AXIsProcessTrustedWithOptions` check

### Feature: Screen Recording Permission

> **Do not bundle this with the Accessibility gate.** They look similar but
> the first-grant semantics are fundamentally different. ScreenCaptureKit
> requires a **full app relaunch** after first grant — Accessibility does not.
> An inline-style flow that polls `SCShareableContent` after grant is the
> single most common bug in this corner of the API.

**Adds:**
- `Sources/ScreenRecordingPermission.swift` — manager with the relaunch invariant encoded in its `Status` enum (`notGranted` / `grantedPendingRelaunch` / `granted`)
- `Sources/ScreenRecordingPromptView.swift` — three-state SwiftUI modal: explain → "Open Settings" → poll → "Relaunch Now"

**Templates location.** `../macos-app-scaffold-new/templates/screen-recording/`
(repo path: `skills/macos-app-scaffold-new/templates/screen-recording/`).
Read its `README.md` before generating — it documents the dev-loop gotchas
the templates exist to prevent.

**Modifies:**
- A Settings tab or feature entry point — present `ScreenRecordingPromptView` as a sheet when the user first reaches a feature that captures the screen
- Any code that calls `SCShareableContent` / `SCStream` / `SCScreenshotManager` — must gate on `ScreenRecordingPermission.shared.isReadyForCapture` (NEVER on `status != .notGranted`, which lets `.grantedPendingRelaunch` through and produces silent failures)

**Detect-and-replace:** if the project already contains a
`ScreenRecordingChecker.swift` (an earlier version of `macos-app-starter`
shipped one), replace it. That earlier file calls
`CGRequestScreenCaptureAccess` and immediately uses `SCShareableContent`
without any relaunch handling — the textbook bug this template exists to
fix. Migrate call sites from `ScreenRecordingChecker.shared.isGranted` to
`ScreenRecordingPermission.shared.isReadyForCapture`.

**Placeholders to substitute:**
- `{{AppName}}` — replace in `ScreenRecordingPromptView.swift` (UI string)

**Tell the user about the dev-loop gotcha (mandatory):**

1. Debug builds must use a stable signing identity. Set
   `CODE_SIGN_IDENTITY: "Apple Development"` (NOT `-`) in `project.yml` for
   the Debug config, and pin `DEVELOPMENT_TEAM`. Re-signing with a different
   identity silently wipes the TCC entry, the System Settings toggle
   disappears, and ScreenCaptureKit returns nothing — without any error.
2. To reproduce the first-grant flow during testing:
   `tccutil reset ScreenCapture <BundleID>`.
3. Do NOT add `NSScreenRecordingUsageDescription` to Info.plist. It is not
   consulted by this API; the system dialog uses `CFBundleDisplayName`.
4. ScreenCaptureKit works under App Sandbox once TCC is granted — no
   entitlement change is needed.

**App Sandbox note:** Unlike Accessibility (which is incompatible with
sandbox), Screen Recording works in sandboxed apps. Mention this if the user
is on the App Store path.

### Feature: Localization

**Adds:** `Localizable.xcstrings` (and `InfoPlist.xcstrings` for display name), plus `LocalizationManager.swift` for runtime language switch.
**Modifies:** `project.yml` to add `Resources/` path, `LOCALIZATION_PREFERS_STRING_CATALOGS: YES`, `SWIFT_EMIT_LOC_STRINGS: YES`, `DEVELOPMENT_LANGUAGE`, and `knownRegions` (must include all selected languages plus `Base`). `AGENTS.md` to add the "no bare UI string literals" convention.

See `macos-app-scaffold-new/SKILL.md` "Localization (if selected)" section for the full template — same xcstrings JSON shape, same project.yml settings, same `LocalizationManager` helper, same AGENTS.md text. Follow the same approach when enhancing.

Ask: Which languages? (always includes English)

- Scan existing Swift files for hardcoded strings that should be localized
- Generate the strings file with discovered keys
- Show how to use `String(localized:)` or `NSLocalizedString`

### Feature: Settings/Preferences Window

**Adds:** `SettingsView.swift`
**Modifies:** App entry point to add `Settings` scene.

- Read existing app entry point to determine where to add the Settings scene
- Generate a tabbed SettingsView scaffold

### Feature: Analytics (Aptabase)

**Modifies:** `project.yml` to add Aptabase SPM dependency.
**Adds:** Analytics initialization in AppDelegate.

- Add package to project.yml
- Add `Aptabase.shared.initialize(appKey: "YOUR_KEY")` in AppDelegate
- Remind user to get their Aptabase app key

### Feature: Onboarding/Welcome Window

**Adds:** `WelcomeView.swift` + window management code.

- Generate SwiftUI welcome view
- Add `UserDefaults` check for first launch
- Show how to present it from AppDelegate

### Feature: Homebrew Cask

**Adds:** A working cask `.rb` file at the chosen tap location, plus (for
topology B) a sibling tap repo skeleton, plus (for topology C) a PR checklist.

Detect first, then ask:
- Detect GitHub remote (`git remote get-url origin`) → owner/repo for the URL.
- Read version from `project.yml` (`MARKETING_VERSION` or top-level `version`).
- Read deployment target from `project.yml` (`DEPLOYMENT_TARGET` /
  `MACOSX_DEPLOYMENT_TARGET`) → maps to `depends_on macos:` codename.
- Detect auto-update mechanism: presence of `Sparkle` SPM dep, or an
  `appcast.xml` file → Sparkle; else look for any GitHub-release polling code
  → `:github_latest`; else default to `:github_latest` for livecheck and omit
  `auto_updates true`.

Then ask the **tap-topology question** — same four options as the new-app
skill (see `macos-app-scaffold-new/SKILL.md` Step 4a). Default to A if the
user mentions an existing tap, otherwise B. Capture `cask_topology`,
`tap_owner`, `tap_repo_name`.

Generate using the template in `macos-app-scaffold-new/SKILL.md` "Homebrew
Cask (if selected)" — same fields (`desc`, `livecheck`, `auto_updates`,
`depends_on`, expanded `zap`), same per-topology destination logic.

If the project has a CI workflow (`.github/workflows/*.yml`) AND topology is
A or B, also append the cask-bump step described in the new-app skill (search
for `Update Homebrew cask in tap repo`). Tell the user to add the
`HOMEBREW_TAP_TOKEN` secret. Do not append the step for C or D.

After writing files, run validation: `brew style ./Casks/<name>.rb`. Report
the result. Defer `brew audit --cask --online` to the user since it requires
the cask to be reachable via a tap.

### Feature: README.md

**Adds:** `README.md` with badges.

- Read project info (name, macOS version, Swift version, license)
- Generate README with build badge, version badge, license badge
- Include build-from-source instructions based on detected build system

### Feature: License

**Adds:** `LICENSE` file.

Ask: MIT / GPL-3.0 / Apache-2.0 / None

### Feature: AGENTS.md + CLAUDE.md

**Adds:** `AGENTS.md` and `CLAUDE.md` symlink.

- Analyze the project and generate conventions based on what's actually there
- Document build commands, tech stack, architecture, CI/CD, secrets
- Create CLAUDE.md as symlink: `ln -s AGENTS.md CLAUDE.md`
- If CLAUDE.md already exists as a regular file, ask before replacing

---

## Step 4: Summary

After all features are added, print:

1. **Files created** — list of new files
2. **Files modified** — list of changed files with what changed
3. **Next steps:**
   - `xcodegen generate` (if project.yml was modified)
   - Any secrets to configure
   - Any manual steps needed (e.g., get Aptabase key, set up Sparkle EdDSA keys)

---

## Feature Name Aliases

For argument-based invocation, accept these aliases:

| Argument | Feature |
|----------|---------|
| `ci-cd`, `ci`, `github-actions` | CI/CD |
| `auto-update`, `update`, `sparkle` | Auto-Update |
| `logging`, `log`, `filelog` | File-Based Logging |
| `swiftlint`, `lint` | SwiftLint |
| `test`, `tests`, `unit-test` | Unit Test Target |
| `launch-at-login`, `login`, `autostart` | Launch at Login |
| `helper`, `agent`, `xpc-helper`, `background-helper` | Background Helper — User Agent |
| `daemon`, `privileged-helper`, `root-helper` | Background Helper — Privileged Daemon |
| `accessibility`, `a11y`, `permission` | Accessibility Gate |
| `screen-recording`, `screencapture`, `sckit`, `screencapturekit` | Screen Recording Permission |
| `localization`, `l10n`, `i18n` | Localization |
| `settings`, `preferences`, `prefs` | Settings Window |
| `analytics`, `aptabase` | Analytics |
| `onboarding`, `welcome` | Onboarding Window |
| `homebrew`, `cask`, `brew` | Homebrew Cask |
| `readme` | README.md |
| `license` | License |
| `agents`, `agents-md`, `claude-md` | AGENTS.md + CLAUDE.md |

---

## Reminders

- Always read existing files before modifying. Never assume structure.
- If `project.yml` exists, it is the single source of truth. Modify it, not `.pbxproj`.
- After modifying `project.yml`, remind the user to run `xcodegen generate`.
- Respect the AGENTS.md / CLAUDE.md symlink convention. Never replace a symlink with a standalone file.
- Use Swift 6.0 conventions (`@MainActor`, `Sendable`) in all generated code.
- Generated code must compile with the existing project. Check imports and types.
- Universal binary support: ensure CI builds use `ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO`.
