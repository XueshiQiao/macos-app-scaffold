---
name: macos-app-scaffold
description: Scaffold a new macOS app or add features to an existing one. Auto-detects project context and routes accordingly.
argument-hint: "[new|enhance] [AppName]"
disable-model-invocation: false
allowed-tools: Bash, Write, Read, Edit, Glob, Grep, Agent, Skill
---

# macOS App Scaffold

Single entry point for macOS app scaffolding. Detects context and routes to the right workflow.

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

**For New App** → Follow the complete flow defined in `macos-app-scaffold-new/SKILL.md`:
1. Ask for app name + bundle ID (use argument if provided)
2. App archetype (Menu Bar / Windowed / Both)
3. Features checklist
4. CI/CD & Distribution
5. Generate everything

**For Enhance** → Follow the complete flow defined in `macos-app-scaffold-enhance/SKILL.md`:
1. Analyze existing project
2. Show status dashboard (what exists vs what can be added)
3. Let user pick features
4. Surgically add selected features

## Reference

The full instructions for each flow are in sibling skill files:
- [New App flow](../macos-app-scaffold-new/SKILL.md)
- [Enhance flow](../macos-app-scaffold-enhance/SKILL.md)

Read and follow those files completely when executing the chosen flow. Do not improvise — use the templates and patterns defined there.
