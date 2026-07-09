import Foundation
import OSLog
import Security

/// Helper executable entry point. Builds as a separate command-line tool
/// target named `{{HelperExecutableName}}` and is embedded at
/// `MyApp.app/Contents/MacOS/{{HelperExecutableName}}` via the launchd plist
/// `BundleProgram` key.
///
/// Lifecycle:
/// - launchd starts this process on demand when something connects to the
///   Mach service named `HelperConstants.machServiceName`.
/// - We hand connections to `HelperListenerDelegate`, which exports a
///   `HelperService` instance per connection.
/// - `dispatchMain()` keeps the process alive. The helper does NOT exit when
///   idle — once started, it stays resident until logout, explicit kill, or
///   the system recycles it. Add an idle-exit timer here if you want
///   true on-demand teardown.

private let log = Logger(subsystem: HelperConstants.machServiceName, category: "lifecycle")

/// Designated requirement that connecting processes must satisfy. Replace
/// `{{AppBundleID}}` and `{{TeamID}}` at scaffold time. Verify the actual
/// requirement of your built app with: `codesign -d -r- /path/to/MyApp.app`.
private let clientRequirement =
    "identifier \"{{AppBundleID}}\" and anchor apple generic " +
    "and certificate leaf[subject.OU] = \"{{TeamID}}\""

/// Validate the connecting process against `clientRequirement` using its PID.
/// This is "good enough" for a user-context helper but is technically
/// vulnerable to PID-reuse races. For stronger guarantees, use the
/// audit_token_t obtained from `xpc_connection_get_audit_token` (private
/// header) with `SecTaskCreateWithAuditToken`.
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
    func ping(reply: @escaping (Int32) -> Void) {
        log.info("ping from pid=\(getpid(), privacy: .public)")
        reply(getpid())
    }

    func performWork(input: String, reply: @escaping (String) -> Void) {
        log.info("performWork input=\(input, privacy: .public)")
        // Real work goes here. Stay non-blocking — XCP replies must come back
        // promptly or the caller's connection times out.
        reply("processed: \(input)")
    }
}

log.info("helper starting, pid=\(getpid(), privacy: .public)")

let listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
let delegate = HelperListenerDelegate()
listener.delegate = delegate
listener.resume()

dispatchMain()
