# Screen Recording Permission (`kTCCServiceScreenCapture`)

A standalone permission flow for ScreenCaptureKit — deliberately separate
from the Accessibility gate, because the two TCC services behave
**fundamentally differently**:

| Concern | Accessibility (`AXIsProcessTrusted`) | Screen Recording (`CGPreflightScreenCaptureAccess`) |
|---|---|---|
| First-grant flow | Inline. User flips the toggle, your running process picks it up live via polling or `kAXTrustedCheckOptionPrompt`. | **Requires a full app relaunch.** ScreenCaptureKit (`SCShareableContent`, `SCStream`, `SCScreenshotManager`) does NOT begin working in the same process the user grants in. |
| Sandbox | Incompatible — Accessibility API requires non-sandbox. | **Compatible.** ScreenCaptureKit works in a sandboxed app once TCC is granted. |
| Info.plist usage string | none | none — the OS fills in the dialog from `CFBundleDisplayName`. Adding `NSScreenRecordingUsageDescription` does nothing. |

If you need both, scaffold both. They are not substitutes for each other.

## Files in this template

| File | Goes to |
|---|---|
| `ScreenRecordingPermission.swift` | App target — `Sources/` |
| `ScreenRecordingPromptView.swift` | App target — `Sources/` (SwiftUI modal) |

Both files reference `{{AppName}}`. Replace before generating.

## The relaunch invariant (read this first)

> ScreenCaptureKit will NOT start working in the same process that the user
> grants permission in. The OS only attaches the new TCC decision to the
> next process the bundle launches.

This is the single mistake that wastes the most debugging time on this API.
Naive implementations look like this:

```swift
// ❌ WRONG: appears to work in the simulator-like grant test, fails on a cold install
if CGRequestScreenCaptureAccess() {
    let content = try await SCShareableContent.current   // throws / returns empty
}
```

The synchronous `CGRequestScreenCaptureAccess` returns `true`, but
`SCShareableContent.current` will throw or return zero displays until the
app has been quit and relaunched. Polling `SCShareableContent` longer does
not help — only a relaunch does.

`ScreenRecordingPermission.swift` encodes this invariant in its `Status` enum:

```swift
case notGranted              // preflight is false
case grantedPendingRelaunch  // preflight is true, but became true mid-session
case granted                 // preflight was true at process start — works now
```

The distinction is preserved by caching `CGPreflightScreenCaptureAccess()`
in `init()` and comparing on each refresh. If preflight transitions
`false → true` during this process lifetime, the status is
`.grantedPendingRelaunch` and your UI MUST surface a "Relaunch Now" button.

`ScreenRecordingPromptView.swift` does this — three branches for the three
states, with `relaunch()` wired to the `.grantedPendingRelaunch` CTA.

## The Xcode dev-loop gotcha (read this second)

> Re-signing your app during development resets its TCC entry. The toggle
> in System Settings silently reverts to off, the app keeps running, and
> ScreenCaptureKit returns nothing. This costs a day of debugging the first
> time you hit it.

TCC keys decisions on the app's stable code-signing identity. If your debug
builds use **ad-hoc signing** (`-` identity) or change designated requirement
between builds (e.g. switching between Personal Team and Apple Development
certs), TCC treats every build as a different application — the previous
grant no longer applies, the toggle is removed silently, and the user is
not re-prompted because the OS has no record of this "new" app.

### Fix: stable signing identity for debug builds

`CODE_SIGN_IDENTITY` is what TCC keys decisions on, so that one MUST be
scoped to Debug only — putting `CODE_SIGN_IDENTITY: "Apple Development"`
under `settings.base` would override the Developer ID identity that CI uses
for Release builds (notarized distribution). `DEVELOPMENT_TEAM` and
`CODE_SIGN_STYLE` are safe to keep in `base` because the same team is
used for both configs, and CI overrides `CODE_SIGN_IDENTITY` at build
time per its own logic.

In `project.yml`:

```yaml
settings:
  base:
    DEVELOPMENT_TEAM: ABCDE12345                   # same team for Debug and Release
    CODE_SIGN_STYLE: Automatic
  configs:
    Debug:
      CODE_SIGN_IDENTITY: "Apple Development"      # NOT "-" (ad-hoc) — TCC needs a stable identity
    # Release: do NOT set CODE_SIGN_IDENTITY here. CI overrides it with the
    # Developer ID signing identity at build time (see .github/workflows/build.yml).
```

This keeps the Debug designated requirement stable across rebuilds, so the
TCC entry survives. If you absolutely must build unsigned (e.g. on CI
without developer credentials), accept that the user will need to re-grant
after each install — document that in your QA runbook.

### Reset commands for testing

```bash
# Reset Screen Recording permission for one app (re-prompts on next request).
tccutil reset ScreenCapture <YourBundleID>

# Reset Screen Recording for ALL apps. Useful when reproducing a first-run flow.
tccutil reset ScreenCapture
```

`tccutil` requires a `<service>` argument — for screen recording the service
name is `ScreenCapture` (singular, matches `kTCCServiceScreenCapture`).
Other useful service names: `Accessibility`, `Microphone`, `Camera`.

## Wiring it into your app

1. Drop both Swift files into `Sources/`. Replace `{{AppName}}` in the prompt
   view with your real app name.

2. In your AppDelegate or a Settings tab, present the modal when the user
   first reaches a screen-recording feature:

   ```swift
   @State private var showsPermissionPrompt = false

   var body: some View {
       Button("Take Screenshot") {
           if ScreenRecordingPermission.shared.isReadyForCapture {
               Task { await captureScreen() }
           } else {
               showsPermissionPrompt = true
           }
       }
       .sheet(isPresented: $showsPermissionPrompt) {
           ScreenRecordingPromptView()
       }
   }
   ```

3. Anywhere you actually call ScreenCaptureKit, gate on
   `isReadyForCapture` — never on `status != .notGranted` (which would
   incorrectly let `.grantedPendingRelaunch` through and silently fail).
   `ScreenRecordingPermission` is `@MainActor`, so reading from
   non-isolated async code requires an explicit hop:

   ```swift
   @MainActor
   func captureScreen() async throws -> CGImage {
       // Same actor as ScreenRecordingPermission — no hop needed.
       guard ScreenRecordingPermission.shared.isReadyForCapture else {
           // Either .notGranted (need to ask) or .grantedPendingRelaunch
           // (need to restart). Trigger the modal instead of calling SCKit.
           throw ScreenCaptureError.relaunchRequired
       }
       let content = try await SCShareableContent.current
       // ...
   }
   ```

   If your capture code can't be `@MainActor`-isolated, await the read
   explicitly:
   ```swift
   let ready = await MainActor.run { ScreenRecordingPermission.shared.isReadyForCapture }
   guard ready else { throw ScreenCaptureError.relaunchRequired }
   ```

4. If your app is sandboxed, no entitlement change is needed — ScreenCaptureKit
   works under sandbox once TCC is granted. Do NOT add a fake entitlement key.

## Common rationalizations to resist

| Excuse | Reality |
|---|---|
| "Polling `SCShareableContent` after grant will eventually pick it up" | It will not. Only a relaunch picks it up. The polling timer in this manager polls **TCC preflight**, not `SCShareableContent` — entirely different. |
| "I'll skip the relaunch button — feels disruptive" | The alternative is silent failure with no error users can act on. The relaunch button is the friendlier path. |
| "I'll just add `NSScreenRecordingUsageDescription` to Info.plist" | It does nothing for this API. The OS dialog uses `CFBundleDisplayName`. |
| "Ad-hoc signing is fine for debug" | Each ad-hoc build is a different app to TCC. You will re-grant constantly and chase ghosts. |
| "I'll piggyback on the Accessibility gate flow" | Different TCC service, different first-grant semantics. Build a separate flow. |
| "I can simplify the manager by dropping `hasObservedFalse`" | That sticky bit is the only signal that distinguishes `granted` from `grantedPendingRelaunch`. Removing it silently breaks the relaunch invariant. |
| "I'll gate calls on `status != .notGranted`" | That lets `.grantedPendingRelaunch` through and you get silent ScreenCaptureKit failures. Gate on `isReadyForCapture`. |

## Red flags — STOP and rethink

- You're polling `SCShareableContent` and waiting for it to "wake up" → you need a relaunch, not more polling.
- You added `NSScreenRecordingUsageDescription` to Info.plist → delete it; it's not consulted.
- Your debug `CODE_SIGN_IDENTITY` is `-` and your toggle "keeps disappearing" → the rebuilds are wiping TCC. Switch to Apple Development.
- You're requesting in `applicationDidFinishLaunching` and immediately calling `SCShareableContent` → on first grant this is the textbook bug. Gate on `isReadyForCapture` only.
