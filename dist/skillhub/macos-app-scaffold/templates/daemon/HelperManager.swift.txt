import Combine
import Foundation
import OSLog
import ServiceManagement

/// App-side controller for the privileged daemon helper.
///
/// Three responsibilities:
/// 1. Register / unregister with `SMAppService`. Unlike `.agent`, the daemon
///    flavor lands in `.requiresApproval` on first registration — the user
///    must flip a switch in System Settings → Login Items & Extensions.
/// 2. Drive the approval UX (`openSystemSettings()`) and observe the status
///    transition from `.requiresApproval` → `.enabled`.
/// 3. Maintain a `.privileged` `NSXPCConnection` for callers.
@MainActor
final class HelperManager: ObservableObject {
    static let shared = HelperManager()

    /// `{{HelperBundleID}}.plist` lives at
    /// `MyApp.app/Contents/Library/LaunchDaemons/{{HelperBundleID}}.plist`.
    private let plistName = "\(HelperConstants.machServiceName).plist"
    private lazy var service = SMAppService.daemon(plistName: plistName)

    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "HelperManager")

    @Published private(set) var status: SMAppService.Status

    private var connection: NSXPCConnection?
    private var pollTimer: Timer?

    private init() {
        self.status = SMAppService.daemon(plistName: "\(HelperConstants.machServiceName).plist").status
    }

    // MARK: Registration

    /// Triggers the system approval prompt on first call. After this returns,
    /// `status` will typically be `.requiresApproval` — surface that to the
    /// user with a "Open System Settings" button wired to `openSystemSettings()`.
    func register() throws {
        try service.register()
        refreshStatus()
        startStatusPolling()
        log.info("registered, status=\(self.status.rawValue, privacy: .public)")
    }

    func unregister() throws {
        try service.unregister()
        teardownConnection()
        stopStatusPolling()
        refreshStatus()
        log.info("unregistered")
    }

    func refreshStatus() {
        let new = service.status
        if new != status {
            log.info("status \(self.status.rawValue, privacy: .public) -> \(new.rawValue, privacy: .public)")
        }
        status = new
        if status == .enabled { stopStatusPolling() }
    }

    /// Deep-link the user to System Settings → Login Items & Extensions
    /// where they can approve the helper.
    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Human-readable hint for the current status. Useful for surfacing in
    /// Settings UI.
    var statusDescription: String {
        switch status {
        case .notRegistered: return "Not installed"
        case .enabled: return "Running"
        case .requiresApproval: return "Waiting for approval in System Settings"
        case .notFound: return "Helper missing — reinstall the app"
        @unknown default: return "Unknown (\(status.rawValue))"
        }
    }

    // MARK: Status polling
    //
    // `.requiresApproval` → `.enabled` happens asynchronously when the user
    // flips the switch in System Settings. There is no notification for this,
    // so we poll while we're waiting.

    private func startStatusPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshStatus() }
        }
    }

    private func stopStatusPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: XPC

    enum HelperError: Error {
        case notApproved        // status is .requiresApproval — call openSystemSettings()
        case notRegistered      // status is .notRegistered or .notFound
        case proxyCastFailed
    }

    /// Returns a remote proxy. Throws if the daemon is not yet enabled
    /// (typically because the user has not approved it in System Settings)
    /// or if the proxy cast fails. Per-call XPC errors are surfaced via the
    /// proxy's own error handler set up in `ensureConnection()`.
    func proxy() throws -> HelperProtocol {
        switch status {
        case .enabled: break
        case .requiresApproval: throw HelperError.notApproved
        default: throw HelperError.notRegistered
        }
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

        // `.privileged` tells XPC this is a system-domain Mach service
        // (registered by a LaunchDaemon, running as root). Without this flag
        // the connection silently fails to find the service.
        let conn = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
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
