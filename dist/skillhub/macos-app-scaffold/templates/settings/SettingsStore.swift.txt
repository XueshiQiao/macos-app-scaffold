import AppKit
import Combine
import ServiceManagement
import SwiftUI

/// The single object the Settings views bind to. Views stay dumb: they read
/// these properties and call these methods; the rules live here.
///
/// **One decision to make before you add anything: own it, or forward it?**
///
/// * **Own it** — the value has no home outside Settings (which page is showing,
///   a cosmetic preference). Store it here as `@Published`, persist it here.
/// * **Forward it** — the value already has an owner elsewhere in the app (the
///   engine that actually uses it, a manager that persists it). Expose a
///   computed pass-through, and republish that owner's `objectWillChange` (see
///   `init`). Do NOT keep a second `@Published` copy.
///
/// The second case is the one that bites. A mirrored copy drifts the moment
/// anything sets one side without the other, and the symptom is the worst kind:
/// the picker shows one value while the running code uses another, and nothing
/// crashes. If a value has an owner, let the owner keep owning it.
@MainActor
final class SettingsStore: ObservableObject {

    // MARK: - Owned by Settings

    /// Which sidebar page is showing. Kept here rather than in `@State` so it
    /// survives any rebuild of the view tree.
    @Published var page: SettingsPage = .general

    /// DELETE this property if "Launch at Login" was NOT selected (and delete
    /// the matching Section in `GeneralPage`). Shipping it unasked registers a
    /// login item the user declined.
    ///
    /// Read live from the system rather than cached: the user can turn this off
    /// in System Settings ▸ General ▸ Login Items, and a remembered "on" would
    /// show a switch that disagrees with the system.
    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("[Settings] launch at login toggle failed: \(error)")
            }
            // Reflect the real post-call state — a failed toggle reverts.
            objectWillChange.send()
        }
    }

    // MARK: - Interface language (optional feature)
    //
    // UNCOMMENT together with the picker Section in `GeneralPage` and the
    // observation block in `SettingsChrome`, ONLY if the in-app
    // interface-language picker was selected. Requires LocalizationOverride.swift.
    //
    //   /// nil means "follow the system".
    //   var interfaceLanguage: String? {
    //       get { LocalizationOverride.storedCode }
    //       set { LocalizationOverride.set(newValue) }
    //   }
    //
    //   var interfaceLanguageCodes: [String] { LocalizationOverride.supportedCodes }

    // MARK: - Status footer
    //
    // Replace both of these with the thing that actually blocks YOUR app —
    // a permission you need, a helper that has not installed. If nothing can
    // block it, delete the footer instead of shipping a light that is always
    // green.

    var isOperational: Bool { true }
    var statusText: String { "Ready" }

    // MARK: - Forwarding (example)
    //
    // Uncomment and adapt when a value's owner lives elsewhere. The relay is
    // what lets the views observe ONE object instead of four.
    //
    //   private var cancellables = Set<AnyCancellable>()
    //
    //   init() {
    //       // Every owner listed here must be a @MainActor ObservableObject.
    //       // That is what makes `assumeIsolated` safe: Swift 6 already refuses
    //       // to compile a mutation of them off the main thread, so their
    //       // objectWillChange can only ever fire on it.
    //       //
    //       // You cannot avoid `assumeIsolated` by declaring the publisher
    //       // `nonisolated let objectWillChange = ObservableObjectPublisher()`
    //       // — that fails to compile, because ObservableObjectPublisher is not
    //       // Sendable.
    //       for owner in [SomeEngine.shared.objectWillChange,
    //                     UpdateManager.shared.objectWillChange] {
    //           owner
    //               .sink { [weak self] in
    //                   MainActor.assumeIsolated { self?.objectWillChange.send() }
    //               }
    //               .store(in: &cancellables)
    //       }
    //   }
    //
    //   var someSetting: SomeType {
    //       get { SomeEngine.shared.someSetting }
    //       set { SomeEngine.shared.someSetting = newValue }
    //   }

    // MARK: - Window lifecycle

    /// Re-read anything that lives outside this app and can change behind our
    /// back — permissions and login-item state are both set in System Settings.
    /// Called on every key-window change, so keep it cheap.
    func refreshPermissionState() {
        // e.g. isTrusted = AXIsProcessTrusted()
        objectWillChange.send()
    }

    /// The fuller refresh for opening the window: everything above, plus
    /// anything too slow to redo on every focus change (an async availability
    /// query, a network check).
    func refreshExternalState() {
        refreshPermissionState()
    }
}
