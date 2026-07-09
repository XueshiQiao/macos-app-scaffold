---
name: macos-app-scaffold
description: Scaffold a new production-grade macOS app or add features (CI/CD, signing, notarization, auto-update, launch-at-login, permission flows) to an existing one. Auto-detects context and routes accordingly.
argument-hint: "[new|enhance] [AppName]"
allowed-tools: Bash, Write, Read, Edit, Glob, Grep
---

# macOS App Scaffold

Single entry point for macOS app scaffolding: create a new production-grade app, or add features to an existing one. Detects context and routes to the right flow. **The two full flows are bundled as separate files in this skill:** `new-app.md` (create from scratch) and `enhance.md` (add to an existing project), plus a `templates/` folder.

## Template files (`.txt` suffix)

Every file under `templates/` has a trailing `.txt` appended **only** to satisfy the uploader's file-type filter — the real type is the *inner* extension. **When you copy a template into the user's project, delete the trailing `.txt`** (e.g. `templates/agent/HelperMain.swift.txt` → `HelperMain.swift`, `templates/agent/LaunchAgent.plist.txt` → `LaunchAgent.plist`, `templates/agent/project.yml.snippet.txt` → `project.yml.snippet`). Same rule for every file under `templates/`.

## Routing Logic

### Step 1: Detect Context

Scan the current directory for signs of an existing macOS project:

```
Look for ANY of these:
- project.yml          (XcodeGen)
- *.xcodeproj/         (Xcode project)
- Package.swift        (SPM executable)
- **/Sources/**App.swift
- **/Info.plist
- *.entitlements
```

### Step 2: Route

**If argument is provided:**
- `$ARGUMENTS` starts with `new` → go to **New App** flow
- `$ARGUMENTS` starts with `enhance` or `add` → go to **Enhance** flow
- Anything else → treat as app name, go to **New App** flow with that name

**If no argument and existing project detected:**

Tell the user what you found, then ask:

```
Detected existing macOS project: {{AppName}}
  (project.yml, Sources/, .github/workflows/, ...)

What would you like to do?
  A) Add features to this project (CI/CD, auto-update, logging, etc.)
  B) Create a brand new app in a subdirectory

> 
```

**If no argument and no project detected:**

```
No macOS project found in the current directory.

What would you like to do?
  A) Create a new macOS app
  B) I'm in the wrong directory — let me navigate first

>
```

### Step 3: Execute

**For New App** → Follow the complete flow defined in `new-app.md`:
1. Ask for app name + bundle ID (use argument if provided)
2. App archetype (Menu Bar / Windowed / Both)
3. Features checklist
4. CI/CD & Distribution
5. Generate everything

**For Enhance** → Follow the complete flow defined in `enhance.md`:
1. Analyze existing project
2. Show status dashboard (what exists vs what can be added)
3. Let user pick features
4. Surgically add selected features

## Reference

The full instructions for each flow are in the bundled files `new-app.md` / `enhance.md`:
- [New App flow → `new-app.md`](new-app.md)
- [Enhance flow → `enhance.md`](enhance.md)

Read and follow that bundled file (`new-app.md` or `enhance.md`) completely when executing the chosen flow. Do not improvise — use the templates and patterns defined there.

## Full flows (bundled files)

- **New App** → read and follow `new-app.md` (bundled with this skill) completely.
- **Enhance** → read and follow `enhance.md` (bundled with this skill) completely.
- Reusable code/config templates are under `templates/` (strip the trailing `.txt` on copy, per the note above).
