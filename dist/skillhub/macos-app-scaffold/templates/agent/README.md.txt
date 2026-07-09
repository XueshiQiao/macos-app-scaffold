# Background Helper — User Agent (`SMAppService.agent`)

A user-context background process registered via `SMAppService.agent(plistName:)`.
Launched on login by `launchd`, runs as the current user, talks to the host app
over `NSXPCConnection`. Use this when you need persistent background work that
does **not** require root (clipboard watcher, sync engine, hotkey daemon, AI
inference worker, etc.).

> If your helper genuinely needs root (VPN, packet filter, system-wide service),
> use the `daemon/` template instead. **Default to agent unless you can name a
> specific privileged operation** the helper must perform.

## Files in this template

| File | Goes to |
|---|---|
| `HelperProtocol.swift` | Shared by app and helper targets |
| `HelperMain.swift` | Helper target entry point (top-level code) |
| `HelperManager.swift` | App target — register/unregister + XPC client |
| `LaunchAgent.plist` | Embedded at `Contents/Library/LaunchAgents/<helper-bundle-id>.plist` |
| `project.yml.snippet` | Append to your `project.yml` |
| `entitlements.snippet.xml` | Helper target entitlements |

## Placeholders to replace

| Placeholder | Example |
|---|---|
| `{{AppBundleID}}` | `me.xueshi.myapp` |
| `{{HelperBundleID}}` | `me.xueshi.myapp.helper` |
| `{{HelperExecutableName}}` | `MyAppHelper` |
| `{{AppName}}` | `MyApp` |
| `{{TeamID}}` | `ABCDE12345` |

The helper Mach service name **must equal** `{{HelperBundleID}}`. Both ends
(`HelperMain.swift`, `HelperManager.swift`, `LaunchAgent.plist`) reference it.

## Wiring it into your app

1. Drop the four Swift files into your project. `HelperProtocol.swift` must be
   compiled into **both** targets.
2. Add the helper target and `Contents/Library/LaunchAgents/` resource path to
   `project.yml` per the snippet.
3. Place `LaunchAgent.plist` (renamed to `{{HelperBundleID}}.plist`) somewhere
   it gets copied into `MyApp.app/Contents/Library/LaunchAgents/`.
4. Run `xcodegen generate` and build.
5. From the app, call `try HelperManager.shared.register()` (e.g. behind a
   Settings toggle). Then obtain the XPC proxy and call methods on it:

   ```swift
   do {
       let helper = try HelperManager.shared.proxy()
       helper.ping { pid in
           print("helper pid: \(pid)")
       }
   } catch {
       print("helper unavailable: \(error)")
   }
   ```

   Per-call XPC errors are reported through the connection's error handler
   (logged via `os_log`); registration / proxy-cast failures throw from
   `proxy()`.

## Testing without rebooting

```bash
# After installing/launching the app once so launchd knows about the agent:
launchctl print gui/$(id -u)/{{HelperBundleID}}            # status
launchctl kickstart -k gui/$(id -u)/{{HelperBundleID}}     # restart
log stream --predicate 'subsystem == "{{HelperBundleID}}"' # live logs

# Reset SMAppService approval state (system-wide; use sparingly):
sudo sfltool resetbtm
```

## Code signing notes

Your CI codesign loop must sign `Contents/MacOS/{{HelperExecutableName}}`
(the helper executable) **before** signing the outer app bundle. The
generated `build.yml` includes a `Contents/Library/Launch{Agents,Daemons}`
sweep — verify it runs against your helper.

Both the app and helper must be signed with the same Team ID and Hardened
Runtime enabled. Notarization applies to the helper too (it ships inside the
app bundle, so a single notarization submission covers it).
