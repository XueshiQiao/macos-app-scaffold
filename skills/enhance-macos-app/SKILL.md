---
name: enhance-macos-app
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
 7. Localization
 8. Settings/Preferences window
 9. Analytics (Aptabase)
 10. Onboarding/Welcome window
 11. Homebrew Cask formula
 12. README.md with badges
 13. License file
 14. AGENTS.md + CLAUDE.md symlink

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
- Add to `project.yml` packages section
- Generate EdDSA key pair instructions
- Add `SUFeedURL` to Info.plist properties
- Show appcast.xml setup instructions

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

### Feature: Accessibility Permission Gate

**Adds:** `PermissionManager.swift`
**Modifies:** `AppDelegate.swift` to call permission check on launch.

- Read existing AppDelegate to find the right insertion point
- Add `AXIsProcessTrustedWithOptions` check

### Feature: Localization

**Adds:** `Localizable.xcstrings` or `.strings` files.
**Modifies:** `project.yml` to add Resources path and localization settings.

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

**Adds:** `Casks/{{appname}}.rb`

- Detect GitHub remote for download URL
- Read version from project.yml
- Generate cask formula template

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
| `accessibility`, `a11y`, `permission` | Accessibility Gate |
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
