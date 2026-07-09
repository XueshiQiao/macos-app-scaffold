# Background Helper — Privileged Daemon (`SMAppService.daemon`)

> **STOP.** Almost no app needs this. A daemon runs as **root**, requires
> explicit user approval through System Settings, and faces a higher Mac App
> Store review bar. If your helper does **not** need root, use the `agent/`
> template instead.
>
> Legitimate reasons to need a daemon:
> - VPN packet tunnel / firewall rules
> - System-wide network proxy
> - Disk / driver / kext-adjacent operations
> - Service that must run before any user logs in
> - System-wide service shared across multiple user accounts
>
> "I want it to start at boot" is **not** a reason — agents start on login,
> and almost every user app only matters when a user is logged in.

A privileged background process registered via `SMAppService.daemon(plistName:)`.
Launched by `launchd` at boot (no login required), runs as root, talks to the
host app over a privileged `NSXPCConnection`.

## Files in this template

| File | Goes to |
|---|---|
| `HelperProtocol.swift` | Shared by app and helper targets |
| `HelperMain.swift` | Helper target entry point (top-level code) |
| `HelperManager.swift` | App target — register/unregister + approval flow + XPC client |
| `LaunchDaemon.plist` | Embedded at `Contents/Library/LaunchDaemons/<helper-bundle-id>.plist` |
| `project.yml.snippet` | Append to your `project.yml` |
| `entitlements.snippet.xml` | Helper target entitlements |

## Placeholders to replace

| Placeholder | Example |
|---|---|
| `{{AppBundleID}}` | `me.xueshi.myapp` |
| `{{HelperBundleID}}` | `me.xueshi.myapp.helper` |
| `{{HelperExecutableName}}` | `MyAppHelper` |
| `{{AppName}}` | `MyApp` |
| `{{TeamID}}` | `ABCDE12345` (find via `security find-identity -p codesigning`) |

## What's different vs. the agent template

| Concern | Agent | Daemon |
|---|---|---|
| Embedded path | `Contents/Library/LaunchAgents/` | `Contents/Library/LaunchDaemons/` |
| Runs as | current user | **root** |
| Starts at | user login | **system boot** |
| User approval | not required | **required** — user must enable in System Settings |
| `NSXPCConnection` options | `[]` | `.privileged` |
| Mach service | published in user domain | published in system domain |
| Plist requires | — | `SMAuthorizedClients` with designated requirement |
| Sandbox | helper can be sandboxed | helper effectively cannot be sandboxed |

The state machine you must handle:

```
.notRegistered  →  call register()  ───────────────┐
                                                    ↓
                              .requiresApproval (typical first run)
                                                    │
                                       user toggles ON in
                                  System Settings → Login Items
                                                    ↓
                                                .enabled
                                                    │
                            user toggles OFF, reboots, etc.
                                                    ↓
                                       back to .requiresApproval / .notRegistered

.notFound  →  helper not embedded correctly, or bundle re-signed with a
              different team ID. Re-check codesigning and embedding.
```

## Critical: caller authorization is YOUR job

A common mistake: assuming `SMAuthorizedClients` in the launchd plist
restricts which processes can connect to the daemon. **It does not.** That
key belongs to the legacy `SMJobBless` flow and is not consulted by launchd
or by SMAppService.

For SMAppService daemons, the registration trust comes from the app and
helper sharing a Team ID inside the same signed bundle. **Runtime XPC client
authorization is enforced in code**, inside the helper's
`shouldAcceptNewConnection` delegate.

`HelperMain.swift` already does this — the `clientIsAuthorized()` function
checks the connecting process against this designated requirement:

```
identifier "{{AppBundleID}}" and anchor apple generic and certificate leaf[subject.OU] = "{{TeamID}}"
```

Verify your app's actual designated requirement after build:

```bash
codesign -d -r- /path/to/MyApp.app
```

Without this check, **any local process** that finds the Mach service can
drive your daemon AS ROOT. Do not delete `clientIsAuthorized()`.

## Wiring it into your app

1. Drop the four Swift files into your project. `HelperProtocol.swift` must
   be compiled into **both** targets.
2. Add the helper target and `Contents/Library/LaunchDaemons/` resource path
   to `project.yml` per the snippet.
3. Place `LaunchDaemon.plist` (renamed to `{{HelperBundleID}}.plist`) so it
   gets copied into `MyApp.app/Contents/Library/LaunchDaemons/`.
4. Run `xcodegen generate` and build with a real Developer ID signing
   identity (ad-hoc signatures will not satisfy `SMAuthorizedClients`).
5. From the app:
   - Call `try HelperManager.shared.register()`.
   - If status becomes `.requiresApproval`, call
     `HelperManager.shared.openSystemSettings()` to deep-link the user.
   - Once status is `.enabled`, obtain the XPC proxy and call methods:

     ```swift
     do {
         let helper = try HelperManager.shared.proxy()
         helper.ping { pid, uid in
             print("daemon pid=\(pid) uid=\(uid)")  // uid should be 0
         }
     } catch HelperManager.HelperError.notApproved {
         HelperManager.shared.openSystemSettings()
     } catch {
         print("daemon unavailable: \(error)")
     }
     ```

   Per-call XPC errors flow through the connection's error handler (logged
   via `os_log`); registration / approval / proxy-cast failures throw from
   `proxy()`.

## Testing without rebooting

```bash
# Status:
sudo launchctl print system/{{HelperBundleID}}

# Restart the helper after a rebuild:
sudo launchctl kickstart -k system/{{HelperBundleID}}

# Live logs:
log stream --predicate 'subsystem == "{{HelperBundleID}}"'

# Why didn't it start? Watch launchd's reasoning:
log stream --predicate 'process == "launchd"' --info | grep {{HelperBundleID}}

# Reset the SMAppService approval database (system-wide; affects ALL apps).
# Use this to reproduce the first-install flow:
sudo sfltool resetbtm
```

## Code signing notes

The daemon executable at `Contents/MacOS/{{HelperExecutableName}}` MUST be
signed before the outer app bundle is sealed. The generated `build.yml`
includes a `Contents/Library/Launch{Agents,Daemons}` and
`Contents/MacOS/<helper>` sweep — verify it covers your helper.

App and helper must share the same Team ID. Both need Hardened Runtime
enabled. Notarize the whole app bundle in one submission (the embedded
helper rides along).

## Mac App Store

App Store *does* allow `SMAppService.daemon`, but reviewers will reject if
the daemon does work that does not require root. Be ready to justify, in
plain language, exactly which privileged operation the helper performs that
cannot be done in-process.
