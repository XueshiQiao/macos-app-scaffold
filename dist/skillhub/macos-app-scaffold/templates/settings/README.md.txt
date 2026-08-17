# Settings window

A sidebar Settings window the app owns, plus the visual system that goes with
it. **It replaces SwiftUI's `Settings` scene. Do not generate one alongside it.**

The `Settings` scene looks like the obvious choice and is wrong for menu-bar
apps in a way that ships easily and annoys forever. This template exists to
stop that specific bug being scaffolded into every new app.

## Files in this template

| File | Goes to | Always? |
|---|---|---|
| `SettingsWindowController.swift` | App target — `Sources/` | Yes |
| `SettingsStore.swift` | App target — `Sources/` | Yes |
| `SettingsChrome.swift` | App target — `Sources/` | Yes |
| `GeneralPage.swift` | App target — `Sources/` | Yes |
| `AboutPage.swift` | App target — `Sources/` | Yes |
| `LocalizationOverride.swift` | App target — `Sources/` | **Only** if the app offers an in-app interface-language picker |

Every file references `{{AppName}}`. Replace before generating.

## The activation invariant (read this first)

> Ordering a window front does not put it in front of the app the user is
> looking at. Only activating the *application* does that — and for an
> `LSUIElement` app nothing activates it automatically.

A menu-bar app is never the frontmost application when the user clicks its
menu-bar icon. `SettingsLink` orders the settings window in **without**
activating the app, so the window opens *behind* whatever the user was looking
at. They then have to go hunting for it through Mission Control. The `Settings`
scene exposes no hook to change this.

```swift
// ❌ WRONG for any LSUIElement app. The window opens behind other apps.
var body: some Scene {
    MenuBarExtra("{{AppName}}", systemImage: "app.fill") { MenuBarView() }
    Settings { SettingsView() }        // ← no way to activate the app first
}
// ...and in the menu:
SettingsLink { Text("Settings…") }     // ← orders front, never activates
```

```swift
// ✅ RIGHT. The app owns the window, so it can activate first.
Button("Settings…") { SettingsWindowController.shared.show() }
```

`show()` does the two lines in the order that matters:

```swift
NSApp.activate(ignoringOtherApps: true)   // put THIS APP in front
window.makeKeyAndOrderFront(nil)          // then this window within it
```

Reversed, or with the first line missing, the bug comes back.

**This applies to every window a menu-bar app opens** — onboarding, an alert
panel, a first-run walkthrough. Same two lines, same order.

## Dropping the `Settings` scene removes ⌘, — put it back

An `LSUIElement` app still has an application menu bar; it appears whenever one
of the app's windows is frontmost. Declaring a `Settings` scene is what puts
"Settings…" (and its ⌘, shortcut) in that menu. Remove the scene and the command
disappears silently — nothing warns you, and a `.keyboardShortcut(",")` on a
button inside the menu-bar menu does **not** restore it, because that shortcut
only exists while that menu is open.

Always pair the owned window with:

```swift
var body: some Scene {
    MenuBarExtra("{{AppName}}", systemImage: "app.fill") { MenuBarView() }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { SettingsWindowController.shared.show() }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
}
```

Verify it landed — the app menu should list "Settings…" with a ⌘, shortcut:

```bash
osascript -e 'tell application "System Events" to tell process "{{AppName}}" \
  to return name of every menu item of menu 1 of menu bar item 2 of menu bar 1'
```

## Why `show()` activates twice

A SwiftUI `MenuBarExtra` menu is still tearing itself down when its button's
action fires, and that teardown takes key status back — the window appears but
is not focused, so the first keystroke goes nowhere. `show()` therefore
re-asserts activation once on the next run loop turn.

An AppKit `NSMenu` does not need this (its action runs after the menu has
closed), so if you build the status menu with `NSMenu` instead of
`MenuBarExtra`, the second pass is harmless but unnecessary.

## Store design: own it, or forward it

`SettingsStore` is the one object the views bind to. Before adding anything to
it, decide which kind of value it is:

| | Own it | Forward it |
|---|---|---|
| **When** | The value has no home outside Settings — which page is showing, a cosmetic preference | The value already has an owner: the engine that uses it, a manager that persists it |
| **How** | `@Published` property, persisted here | Computed pass-through + republish the owner's `objectWillChange` |
| **Never** | — | A second `@Published` copy |

The forwarding case is the one that bites. A mirrored copy drifts the moment
anything sets one side without the other, and the symptom is quiet: the picker
shows one value while the running code uses another. Nothing crashes; the user
just reports that the setting "doesn't work sometimes".

Republishing needs `MainActor.assumeIsolated` inside the Combine sink. That is
safe **only** because every owner you relay from is a `@MainActor`
`ObservableObject` — Swift 6 then refuses to compile any off-main mutation, so
their `objectWillChange` can only fire on the main thread. Do not relay from a
non-`@MainActor` object; `assumeIsolated` traps rather than warns.

You cannot dodge it by declaring the publisher non-isolated —
`nonisolated let objectWillChange = ObservableObjectPublisher()` fails to
compile, because `ObservableObjectPublisher` is not `Sendable`.

## The visual system

`SettingsChrome.swift` holds everything visual so the pages stay about their own
content:

| Piece | Use |
|---|---|
| `auroraBackground()` | The window's soft gradient wash. Opaque base on purpose — a translucent one makes the vibrancy re-sample the desktop every scroll frame |
| `IconTile` / `AssetIconTile` | 26pt coloured tile with a white glyph — the leading element of nearly every row |
| `HeroTile` | The same tile at 68pt, for a window with one thing to say (onboarding, empty state) |
| `iconLabel` / `featureLabel` / `optionRow` | Row builders. `featureLabel` adds a wrapping subtitle — that is where a setting earns its keep |
| `GrantedPill` | Green capsule for a state you report rather than a control you offer |
| `SidebarIcon` / `StatusDot` | Sidebar row icon; footer health light |

**Adding a page:** add a case to `SettingsPage` (title, symbol, colour, `axID`),
add a branch in `SettingsRootView`, write the page as a
`Form { … }.formStyle(.grouped).navigationTitle(…)`. Nothing else to wire.

Two rules the template encodes, worth keeping:

- **A permission is two states, not a toggle.** Granted is a fact to report
  (`GrantedPill`); not-granted is an action to offer (a button). A toggle
  implies the app can revoke it, which it cannot.
- **The status footer must be able to be orange.** Point it at the thing that
  actually blocks your app. A light that is green no matter what is worse than
  no light — delete the footer instead.

## Optional: in-app interface-language picker

Only copy `LocalizationOverride.swift` if the app genuinely needs to switch its
own UI language without a relaunch. The cost is app-wide and permanent:

> **Every user-facing string in the app must go through `L("…")`.**

The override works by intercepting `Bundle.localizedString(forKey:value:table:)`,
which is what `NSLocalizedString` calls. SwiftUI's automatic `LocalizedStringKey`
lookup (a bare `Text("Quit")`) and `String(localized:)` are **not** documented to
route through it. Anything left in those forms keeps rendering in the *system*
language, and the failure is partial and quiet — the Settings window switches
while the menu-bar menu does not.

Second cost: `L`'s argument is a variable, so Xcode's string extractor cannot see
these call sites. Every new string must be added to the String Catalog by hand,
in every language.

### Wiring it — all five steps, or it does not work

Copying the file is not enough. Every step below has a silent failure mode.

1. **Copy `LocalizationOverride.swift`** into `Sources/`.
2. **Call `LocalizationOverride.applyStored()` in `applicationWillFinishLaunching`**
   — not `applicationDidFinishLaunching`. Strings read during scene setup
   resolve before the later hook runs, so the first thing the user sees would be
   in the system language.
3. **Uncomment the picker** — the `Section` in `GeneralPage.swift`, and the
   `interfaceLanguage` / `interfaceLanguageCodes` pass-throughs in
   `SettingsStore.swift`. Without this the feature is advertised and absent:
   the machinery ships, but there is no UI to change anything.
4. **Observe the revision counter on every visible surface** — the Settings root
   (uncomment both marked lines in `SettingsChrome.swift`), the menu-bar menu,
   and any other window:
   ```swift
   @ObservedObject private var languageRevision = LanguageRevision.shared   // subscribe
   …
   .id(languageRevision.value)                                             // rebuild
   ```
   **Both lines.** `.id(LanguageRevision.shared.value)` on its own reads the
   counter without subscribing, so SwiftUI is never told it changed and the
   surface keeps its old language until some unrelated redraw. The symptom is
   "the picker works sometimes".
5. **Convert every user-facing string to `L("…")`** and add them to the String
   Catalog by hand.

### Do not combine it with an `AppleLanguages` switcher

A common alternative writes the chosen code to the `AppleLanguages` user
default. **That cannot switch a running app** — `Bundle.main` has already
resolved its localization, and no amount of rebuilding the view tree changes
that; it takes effect on the next launch. Pick one mechanism:

| Mode | Mechanism | Strings written as |
|---|---|---|
| Follow the system (default) | nothing — macOS resolves it | `String(localized:)` or bare `Text("…")` |
| Instant in-app switch | `LocalizationOverride` only | `L("…")` |

Running both leaves two independent preferences and a picker that appears to
work and does not. If the app is single-language, or is happy following the
system, skip this file entirely and keep bare SwiftUI literals.

## Other traps this template already handles

| Trap | What happens | Handled by |
|---|---|---|
| `@Environment(\.dismiss)` in a hand-made `NSWindow` | Does nothing. A "Done" button that silently fails | Pass an explicit close callback into the view instead |
| `isReleasedWhenClosed` left `true` | Reopening rebuilds the whole SwiftUI tree and loses sidebar/scroll state | Set to `false`; the controller keeps the reference |
| Permission revoked while the window stays open | Page keeps showing "Granted" forever, because `show()` never runs again | `windowDidBecomeKey` → `refreshPermissionState()` |
| Row only clickable on its icon and text | The gaps between them are dead; the row feels broken | `.contentShape(Rectangle())` on the row's label |

## Verifying it

Headless checks — do these yourself.

A settings window is a pile of SwiftUI that only one page of shows at a time, so
a page can be broken for weeks before anyone clicks it. Add this launch hook
(`SettingsPage(axID:)` in `SettingsChrome.swift` exists for it) so every page can
be built and checked without a mouse:

```swift
// in applicationDidFinishLaunching
if let want = ProcessInfo.processInfo.environment["OPEN_SETTINGS"], want != "0" {
    Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(700))
        SettingsWindowController.shared.show(page: SettingsPage(axID: want))
    }
}
```

```bash
# every page builds and does not crash
for page in general about; do
  pkill -x {{AppName}}; sleep 1
  open ".../{{AppName}}.app" --env OPEN_SETTINGS=$page
  sleep 3; pgrep -x {{AppName}} >/dev/null && echo "$page ok" || echo "$page CRASHED"
done
```

**The activation fix cannot be verified headlessly.** Whether the window really
lands in front of another app depends on the window server: on a locked or
sleeping screen macOS suppresses activation entirely, `NSApp.isActive` stays
false, and a screenshot comes back black. That is not the bug — it is the lock.
Ask a human at an unlocked screen to do this one:

1. Put another app fullscreen in front.
2. Click the menu-bar icon → "Settings…".
3. **Expect:** the window is immediately in front and focused, with no hunting.
