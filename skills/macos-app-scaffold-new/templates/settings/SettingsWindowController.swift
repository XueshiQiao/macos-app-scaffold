import AppKit
import SwiftUI

/// Hosts the Settings UI in a window the app owns.
///
/// **This deliberately replaces SwiftUI's `Settings` scene. Do not add one back.**
///
/// For a menu-bar app (`LSUIElement: true`) the `Settings` scene is broken in a
/// way that is easy to ship and annoying to live with: the app is never the
/// frontmost application when the user clicks its menu-bar icon, and
/// `SettingsLink` orders the settings window in *without activating the app*.
/// The window opens behind whatever the user was looking at, and they have to go
/// hunting for it. The `Settings` scene exposes no hook to fix that.
///
/// Owning the window means `show()` can activate the app first and then order
/// the window front — two lines, in that order, which is the whole fix.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {

    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private let store = SettingsStore()

    /// Bring the window up, creating it on first use.
    /// - Parameter page: jump straight to a page. Normal opens pass nil, so the
    ///   user lands back on whichever page they were last looking at.
    func show(page: SettingsPage? = nil) {
        if let page { store.page = page }
        store.refreshExternalState()

        let window = window ?? makeWindow()
        if !window.isVisible { window.center() }
        bringToFront(window)

        // And again once this run loop turn is over. When the caller is a
        // SwiftUI `MenuBarExtra` menu item, that menu is still tearing itself
        // down as the action fires, and its dismissal takes key status back —
        // leaving the window on screen but not focused. An AppKit `NSMenu` does
        // not have this problem (its action runs after the menu has closed), so
        // this second pass is only needed for the SwiftUI menu.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            self.bringToFront(window)
        }
    }

    private func bringToFront(_ window: NSWindow) {
        // Order matters. Activating the app is what puts the window in front of
        // the OTHER app the user is looking at; `makeKeyAndOrderFront` alone
        // only orders it within this app's own windows.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let root = SettingsRootView().environmentObject(store)
        let window = NSWindow(contentViewController: NSHostingController(rootView: root))
        window.title = "{{AppName}} Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        // Keep the window alive across closes so the sidebar selection and
        // scroll position survive, and reopening does not rebuild the whole
        // SwiftUI tree.
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 820, height: 580))
        // Restores the size the user resized to. `center()` below then
        // overrides the saved POSITION on purpose — a settings window is opened
        // rarely, and landing somewhere predictable beats landing where it was
        // left on a monitor that may no longer be attached.
        window.setFrameAutosaveName("{{AppName}}Settings")
        window.center()
        window.delegate = self
        self.window = window
        return window
    }

    /// Hide rather than close. For a menu-bar app, closing the last window must
    /// not read as "quit". Harmless for a windowed app too.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    /// The window outlives its closes, so coming back to it does not
    /// necessarily go through `show()`. Someone who steps out to System
    /// Settings, changes a permission, and clicks straight back onto this window
    /// would otherwise be looking at a stale answer.
    func windowDidBecomeKey(_ notification: Notification) {
        store.refreshPermissionState()
    }
}
