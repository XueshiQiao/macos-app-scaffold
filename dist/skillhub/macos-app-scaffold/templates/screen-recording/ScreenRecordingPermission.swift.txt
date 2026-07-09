import AppKit
import Combine
import CoreGraphics

/// Manages the `kTCCServiceScreenCapture` permission with the one invariant
/// that catches almost every naive implementation: ScreenCaptureKit
/// (`SCShareableContent`, `SCStream`, `SCScreenshotManager`) will NOT start
/// working in the same process that the user grants permission in. The OS
/// only attaches the new TCC decision to the next process the bundle launches.
/// You MUST quit and relaunch the app on first grant.
///
/// The CGWindowList / CGDisplayCreateImage legacy paths share the same TCC
/// service, but in practice some callers report that they start working
/// without a relaunch. Do not rely on it. Always treat first-grant as
/// requiring a relaunch.
@MainActor
final class ScreenRecordingPermission: ObservableObject {
    static let shared = ScreenRecordingPermission()

    enum Status: Equatable {
        /// Preflight returns false — never asked, denied, or revoked.
        case notGranted
        /// Preflight is true, but it became true during this process lifetime.
        /// ScreenCaptureKit will not work until the user relaunches the app.
        case grantedPendingRelaunch
        /// Preflight was already true at process start. ScreenCaptureKit works.
        case granted
    }

    @Published private(set) var status: Status

    /// `true` only when ScreenCaptureKit is actually safe to call — i.e.
    /// status is `.granted`. `.grantedPendingRelaunch` returns `false` here
    /// even though TCC says yes, because the framework will not have
    /// observed the new decision yet. Always gate ScreenCaptureKit calls on
    /// this property, NEVER on `status != .notGranted`.
    var isReadyForCapture: Bool { status == .granted }

    /// Sticky bit that goes true the moment we ever observe preflight as
    /// false in this process (including at process start). Once true, any
    /// subsequent `true` reading is treated as `.grantedPendingRelaunch`,
    /// not `.granted`. This handles two cases with a single flag:
    ///   1. App launches without permission, user grants mid-session
    ///      → flag is true from init → status reaches `.grantedPendingRelaunch`.
    ///   2. App launches with permission, user revokes then re-grants in the
    ///      same session → flag flips true on the revoke → status reaches
    ///      `.grantedPendingRelaunch` after the re-grant. Defensive: TCC's
    ///      grant-during-session behavior under revoke/regrant is not
    ///      formally documented; treating it like first-grant is the safe
    ///      assumption.
    /// DO NOT REMOVE this field "as a simplification" — it is the only
    /// signal that distinguishes "granted in a previous launch
    /// (ScreenCaptureKit works)" from "granted mid-session (ScreenCaptureKit
    /// will return nothing until relaunch)". Without it, the relaunch
    /// invariant is silently broken.
    private var hasObservedFalse: Bool

    private var pollTimer: Timer?

    private init() {
        let initial = CGPreflightScreenCaptureAccess()
        self.hasObservedFalse = !initial
        self.status = initial ? .granted : .notGranted
    }

    /// Re-read the cached TCC decision. Safe to call repeatedly — never prompts.
    func refresh() {
        let now = CGPreflightScreenCaptureAccess()
        if now {
            status = hasObservedFalse ? .grantedPendingRelaunch : .granted
        } else {
            hasObservedFalse = true
            status = .notGranted
        }
    }

    /// First call per app install surfaces the system prompt. Subsequent
    /// calls return the cached decision without prompting — when that is
    /// `false` the only way forward is System Settings, so we deep-link.
    func requestPermission() {
        let granted = CGRequestScreenCaptureAccess()
        if granted {
            status = hasObservedFalse ? .grantedPendingRelaunch : .granted
        } else {
            hasObservedFalse = true
            openSystemSettings()
            status = .notGranted
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Last error from `relaunch()`, if any. Surface this in your UI when
    /// non-nil — the relaunch failed and the user is still in the original
    /// process.
    @Published private(set) var relaunchError: Error?

    /// Quit + relaunch via `NSWorkspace.openApplication`. Required after
    /// first grant for ScreenCaptureKit to begin working. Call from the
    /// `.grantedPendingRelaunch` branch of your modal.
    ///
    /// Uses `NSWorkspace.openApplication` (not `Process`/`open -n -a`) so
    /// this also works under App Sandbox. `createsNewApplicationInstance`
    /// forces a fresh process even if the OS still considers this one alive.
    /// We terminate ONLY from the success branch of the completion handler:
    /// if the launch failed (stale bundle path, sandbox launch denial,
    /// missing on-disk app), terminating without a replacement would silently
    /// quit the user with no app to come back to.
    func relaunch() {
        relaunchError = nil
        let bundleURL = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { [weak self] _, error in
            Task { @MainActor in
                if let error = error {
                    self?.relaunchError = error
                    NSLog("ScreenRecordingPermission relaunch failed: \(error.localizedDescription). Not terminating; user can retry or quit manually.")
                    return
                }
                NSApp.terminate(nil)
            }
        }
    }

    /// While a permission modal is on screen, poll preflight on a timer so
    /// the modal updates the moment the user flips the toggle in System
    /// Settings (which happens out of process — no notification fires).
    func startPolling(interval: TimeInterval = 1.0) {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
