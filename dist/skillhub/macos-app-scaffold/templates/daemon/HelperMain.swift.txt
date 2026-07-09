import Foundation
import OSLog
import Security

/// Privileged helper entry point. Builds as a separate command-line tool
/// target named `{{HelperExecutableName}}` and is embedded at
/// `MyApp.app/Contents/MacOS/{{HelperExecutableName}}` via the launchd plist
/// `BundleProgram` key.
///
/// Runs as root once the user approves it in
/// System Settings → Login Items & Extensions.
///
/// Lifecycle:
/// - launchd starts this process on demand when something connects to the
///   Mach service named `HelperConstants.machServiceName`.
/// - Each connection gets its own `HelperService` instance.
/// - `dispatchMain()` keeps the process alive. The helper does NOT exit
///   when idle — it stays resident until launchd kills it. That is normal
///   for SMAppService daemons.
///
/// IMPORTANT: caller authorization is the helper's responsibility. launchd
/// does not consult `SMAuthorizedClients` here (that key belongs to the
/// legacy SMJobBless flow, not SMAppService). Without the validation below,
/// any local process that can find the Mach service can drive this daemon
/// AS ROOT. Do not delete `clientIsAuthorized()`.

private let log = Logger(subsystem: HelperConstants.machServiceName, category: "lifecycle")

/// Designated requirement that connecting processes must satisfy. Replace
/// `{{AppBundleID}}` and `{{TeamID}}` at scaffold time. Verify the actual
/// requirement of your built app with: `codesign -d -r- /path/to/MyApp.app`.
private let clientRequirement =
    "identifier \"{{AppBundleID}}\" and anchor apple generic " +
    "and certificate leaf[subject.OU] = \"{{TeamID}}\""

/// Validate the connecting process against `clientRequirement` using its PID.
/// "Good enough" for most cases but technically vulnerable to PID-reuse
/// races. For a hardened daemon, get the audit_token_t via
/// `xpc_connection_get_audit_token` (private header) and pair it with
/// `SecTaskCreateWithAuditToken`.
private func clientIsAuthorized(_ connection: NSXPCConnection) -> Bool {
    let attributes = [kSecGuestAttributePid as String: connection.processIdentifier] as CFDictionary
    var code: SecCode?
    guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
          let code = code else { return false }

    var requirement: SecRequirement?
    guard SecRequirementCreateWithString(clientRequirement as CFString, [], &requirement) == errSecSuccess,
          let requirement = requirement else { return false }

    return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
}

final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection conn: NSXPCConnection) -> Bool {
        guard clientIsAuthorized(conn) else {
            log.error("rejected connection from pid=\(conn.processIdentifier, privacy: .public) — does not match client requirement")
            return false
        }

        let interface = NSXPCInterface(with: HelperProtocol.self)
        conn.exportedInterface = interface
        conn.exportedObject = HelperService()

        conn.invalidationHandler = {
            log.info("connection invalidated")
        }
        conn.interruptionHandler = {
            log.info("connection interrupted")
        }

        conn.resume()
        log.info("accepted connection from pid=\(conn.processIdentifier, privacy: .public)")
        return true
    }
}

final class HelperService: NSObject, HelperProtocol {
    func ping(reply: @escaping (Int32, UInt32) -> Void) {
        log.info("ping pid=\(getpid(), privacy: .public) uid=\(getuid(), privacy: .public)")
        reply(getpid(), getuid())
    }

    func performPrivilegedWork(input: String, reply: @escaping (String) -> Void) {
        // Real privileged work goes here. Validate inputs aggressively — this
        // process runs as root, and the caller is an unprivileged GUI app.
        log.info("performPrivilegedWork input=\(input, privacy: .public)")
        reply("processed-as-root: \(input)")
    }
}

log.info("daemon starting, pid=\(getpid(), privacy: .public) uid=\(getuid(), privacy: .public)")

let listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
let delegate = HelperListenerDelegate()
listener.delegate = delegate
listener.resume()

dispatchMain()
