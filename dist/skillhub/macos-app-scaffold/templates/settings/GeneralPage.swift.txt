import SwiftUI

/// The everyday settings. Keep this page short — it is the one people actually
/// open, and every row you add here makes the important ones harder to find.
struct GeneralPage: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        Form {
            // ─────────────────────────────────────────────────────────
            // DELETE this Section if "Launch at Login" was NOT selected.
            // Also delete `launchAtLogin` from SettingsStore — an app that
            // silently registers a login item the user declined is worse than
            // one that never offered it.
            // ─────────────────────────────────────────────────────────
            Section {
                Toggle(isOn: Binding(get: { store.launchAtLogin },
                                     set: { store.launchAtLogin = $0 })) {
                    iconLabel("power", .green, "Launch at login")
                }
            }

            // ─────────────────────────────────────────────────────────
            // UNCOMMENT this Section ONLY if the in-app interface-language
            // picker was selected (it needs LocalizationOverride.swift).
            // Without it there is no way to change language, and the feature
            // is advertised but absent.
            // ─────────────────────────────────────────────────────────
            //
            // Section {
            //     Picker(selection: Binding(
            //         get: { store.interfaceLanguage ?? Self.systemTag },
            //         set: { store.interfaceLanguage = ($0 == Self.systemTag ? nil : $0) }
            //     )) {
            //         Text(L("Follow system")).tag(Self.systemTag)
            //         ForEach(store.interfaceLanguageCodes, id: \.self) { code in
            //             // Each language in its own words: someone who landed
            //             // in a language they cannot read still recognises theirs.
            //             Text(verbatim: LocalizationOverride.nativeName(for: code)).tag(code)
            //         }
            //     } label: {
            //         featureLabel("character.square", .cyan,
            //                      L("Interface language"),
            //                      L("The language {{AppName}}'s own windows and menus are written in."))
            //     }
            //     .pickerStyle(.menu)
            // }

            // A permission row, if the app needs one. Two states, not one
            // toggle: granted is a fact to report, not-granted is an action to
            // offer. A toggle would imply the app can revoke it, which it can't.
            //
            // Section {
            //     LabeledContent {
            //         if store.accessibilityGranted {
            //             GrantedPill(text: "Granted")
            //         } else {
            //             Button("Grant Accessibility…") { store.requestAccessibility() }
            //         }
            //     } label: {
            //         featureLabel("accessibility", .blue,
            //                      "Accessibility permission",
            //                      "{{AppName}} needs this to read other apps' windows. Without it, it can see nothing at all.")
            //     }
            // }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }

    /// Tag standing in for "no override" — a `Picker` needs a concrete value and
    /// nil is not one. Shaped so it can never collide with a real BCP-47 code.
    private static let systemTag = "__system__"
}
