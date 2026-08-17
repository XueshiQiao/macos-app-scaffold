import Combine
import Foundation
import ObjectiveC

// OPTIONAL — only copy this file if the app offers an in-app interface-language
// picker (one that switches language without a relaunch, independent of the
// system language). It has a real cost; read `README.md` before adopting it.

extension Notification.Name {
    /// Posted after the interface language changes. Every visible surface
    /// observes this and rebuilds, so labels switch without a relaunch.
    static let appLanguageChanged = Notification.Name("{{AppName}}LanguageChanged")
}

/// Look up a user-facing string in the (possibly overridden) main bundle.
///
/// **Once you adopt this, EVERY user-facing string in the app must go through
/// `L(...)`.** `LocalizationOverride` works by intercepting
/// `Bundle.localizedString(forKey:value:table:)` — the method `NSLocalizedString`
/// calls. SwiftUI's automatic `LocalizedStringKey` lookup (a bare
/// `Text("Quit")`) and `String(localized:)` are not documented to route through
/// it, so any string left in those forms keeps rendering in the SYSTEM language
/// after the user picks another one. The failure is partial and quiet: the
/// Settings window switches, the menu-bar menu doesn't.
///
/// Second cost: because `L`'s argument is a variable, Xcode's string extractor
/// cannot see these call sites. New strings must be added to the String Catalog
/// by hand, in every language.
func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// Per-app override of the language `NSLocalizedString` renders in.
///
/// macOS resolves localized strings through `Bundle.main`. To switch language
/// inside a running process we swap `Bundle.main`'s class for a subclass that
/// consults a sub-bundle (e.g. `ja.lproj`) while an override is active, and
/// falls through to normal system resolution otherwise.
enum LocalizationOverride {

    private static let defaultsKey = "settings.interfaceLanguage"

    /// Codes actually shipped in the built bundle. Read from the bundle rather
    /// than hard-coded, so the picker can never offer a language whose `.lproj`
    /// was dropped from the build.
    static let supportedCodes: [String] = {
        Bundle.main.localizations.filter { $0 != "Base" }.sorted()
    }()

    /// Guarded by a lock rather than pinned to the main actor, because the two
    /// sides really do run on different threads: written from the main thread
    /// (launch, and the picker), but read inside `localizedString(forKey:)`,
    /// which anything on any thread can call. `nonisolated(unsafe)` is safe here
    /// ONLY because every access goes through `lock`.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _activeBundle: Bundle?

    fileprivate static var activeBundle: Bundle? {
        get { lock.lock(); defer { lock.unlock() }; return _activeBundle }
        set { lock.lock(); defer { lock.unlock() }; _activeBundle = newValue }
    }

    /// The saved preference: a BCP-47 code, or nil for "follow system".
    static var storedCode: String? {
        let saved = UserDefaults.standard.string(forKey: defaultsKey) ?? ""
        return saved.isEmpty ? nil : saved
    }

    /// Apply a language to the running process. Idempotent, and safe to call
    /// before any UI exists — which is exactly when you must call it. Put
    /// `applyStored()` in `applicationWillFinishLaunching`, NOT
    /// `applicationDidFinishLaunching`: strings read during scene setup would
    /// otherwise resolve in the system language.
    static func apply(code: String?) {
        let cls: AnyClass = LanguageOverrideBundle.self
        if object_getClass(Bundle.main) != cls {
            object_setClass(Bundle.main, cls)
        }
        if let code,
           let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            activeBundle = bundle
        } else {
            activeBundle = nil
        }
    }

    /// Persist a choice, apply it, and tell the UI to rebuild.
    static func set(_ code: String?) {
        UserDefaults.standard.set(code ?? "", forKey: defaultsKey)
        apply(code: code)
        NotificationCenter.default.post(name: .appLanguageChanged, object: nil)
    }

    static func applyStored() { apply(code: storedCode) }

    /// A language's name in its own language ("English", "简体中文", "日本語").
    /// Shown that way on purpose: someone who has landed in a language they
    /// cannot read needs to recognise their own by sight.
    static func nativeName(for code: String) -> String {
        Locale(identifier: code).localizedString(forIdentifier: code) ?? code
    }
}

/// A counter every visible surface keys its identity off, so a language change
/// rebuilds it.
///
/// SwiftUI has no reason to re-render a view because a bundle swapped
/// underneath it — the view's own inputs did not change. Bumping this is what
/// forces the re-read. One shared counter, so the menu-bar menu and the
/// Settings window can never render two different languages at once.
///
/// **Every surface must OBSERVE it, not just read it.** Both lines are
/// required:
///
/// ```swift
/// struct MenuBarView: View {
///     @ObservedObject private var languageRevision = LanguageRevision.shared   // subscribe
///     var body: some View {
///         Group { … }
///             .id(languageRevision.value)                                      // rebuild
///     }
/// }
/// ```
///
/// Writing `.id(LanguageRevision.shared.value)` alone reads the counter without
/// subscribing to it. SwiftUI is then never told the value changed, so the
/// surface keeps rendering the previous language until some unrelated redraw
/// happens to refresh it — which looks like "the picker works sometimes".
@MainActor
final class LanguageRevision: ObservableObject {
    static let shared = LanguageRevision()

    @Published private(set) var value = 0

    private init() {
        NotificationCenter.default.addObserver(
            forName: .appLanguageChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.value &+= 1 }
        }
    }
}

private final class LanguageOverrideBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let lprojBundle = LocalizationOverride.activeBundle {
            return lprojBundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}
