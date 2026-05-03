import Combine
import Foundation
import OSLog
import ServiceManagement

/// App-side controller for the user agent helper.
///
/// Two responsibilities:
/// 1. Register / unregister the helper with `SMAppService` and observe its
///    state. The agent flavor does NOT require user approval, so the state
///    machine is simpler than the daemon's: `.notRegistered` → `.enabled`.
/// 2. Maintain a long-lived `NSXPCConnection` so callers can just call
///    `HelperManager.shared.proxy.ping { … }` without worrying about
///    connection lifecycle.
@MainActor
final class HelperManager: ObservableObject {
    static let shared = HelperManager()

    /// `{{HelperBundleID}}.plist` lives at
    /// `MyApp.app/Contents/Library/LaunchAgents/{{HelperBundleID}}.plist`.
    private let plistName = "\(HelperConstants.machServiceName).plist"
    private lazy var service = SMAppService.agent(plistName: plistName)

    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "HelperManager")

    @Published private(set) var status: SMAppService.Status

    private var connection: NSXPCConnection?

    private init() {
        self.status = SMAppService.agent(plistName: "\(HelperConstants.machServiceName).plist").status
    }

    // MARK: Registration

    func register() throws {
        try service.register()
        refreshStatus()
        log.info("registered, status=\(self.status.rawValue, privacy: .public)")
    }

    func unregister() throws {
        try service.unregister()
        teardownConnection()
        refreshStatus()
        log.info("unregistered")
    }

    func refreshStatus() {
        status = service.status
    }

    // MARK: XPC

    enum HelperError: Error {
        case notRegistered
        case proxyCastFailed
    }

    /// Returns a remote proxy. Throws if the helper is not registered or if
    /// the proxy cast fails (programmer error — `HelperProtocol` mismatch
    /// between app and helper targets). Per-call XPC errors are surfaced via
    /// the proxy's own error handler set up in `ensureConnection()`.
    func proxy() throws -> HelperProtocol {
        guard status == .enabled else { throw HelperError.notRegistered }
        let conn = ensureConnection()
        guard let proxy = conn.remoteObjectProxyWithErrorHandler({ [weak self] error in
            self?.log.error("XPC error: \(String(describing: error), privacy: .public)")
            Task { @MainActor [weak self] in self?.teardownConnection() }
        }) as? HelperProtocol else {
            throw HelperError.proxyCastFailed
        }
        return proxy
    }

    private func ensureConnection() -> NSXPCConnection {
        if let conn = connection { return conn }

        let conn = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: [])
        conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.log.info("connection invalidated")
                self?.connection = nil
            }
        }
        conn.interruptionHandler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.log.info("connection interrupted")
                self?.connection = nil
            }
        }
        conn.resume()
        connection = conn
        return conn
    }

    private func teardownConnection() {
        connection?.invalidate()
        connection = nil
    }
}
