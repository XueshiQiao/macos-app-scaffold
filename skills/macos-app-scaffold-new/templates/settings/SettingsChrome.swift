import AppKit
import SwiftUI

// The Settings window's shared visual language — aurora background, coloured
// icon tiles, sidebar icons, status dot — plus the root `NavigationSplitView`
// that hosts the sidebar and the detail pages.
//
// Everything visual lives here so the pages stay about their own content. Add a
// page by adding a case to `SettingsPage` and a branch in `SettingsRootView`.

// MARK: - Sidebar pages

enum SettingsPage: Hashable, CaseIterable {
    case general, about

    var title: String {
        switch self {
        case .general: return "General"
        case .about:   return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .about:   return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: return Color(nsColor: .systemGray)
        case .about:   return .pink
        }
    }

    /// Stable, language-independent id stem for accessibility identifiers, so a
    /// UI test can find a row without depending on the rendered language.
    var axID: String {
        switch self {
        case .general: return "general"
        case .about:   return "about"
        }
    }

    /// Look a page up by its `axID`, for a launch-time hook that opens the
    /// window straight onto one page (see README — it is how you check every
    /// page builds without clicking through them).
    init?(axID: String) {
        guard let match = Self.allCases.first(where: { $0.axID == axID }) else { return nil }
        self = match
    }
}

// MARK: - Aurora background

extension View {
    /// The signature soft aurora wash, composited over an OPAQUE window base.
    /// Opaque matters: paired with `.scrollContentBackground(.hidden)` on the
    /// Form, a translucent wash lets the window's vibrancy re-sample the desktop
    /// on every scroll frame.
    func auroraBackground() -> some View {
        background(
            Color(nsColor: .windowBackgroundColor)
                .overlay(
                    LinearGradient(colors: [Color(.sRGB, red: 0.40, green: 0.55, blue: 1.00, opacity: 0.10),
                                            Color(.sRGB, red: 1.00, green: 0.55, blue: 0.85, opacity: 0.07),
                                            Color(.sRGB, red: 0.35, green: 0.85, blue: 0.70, opacity: 0.08)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                .ignoresSafeArea()
        )
    }
}

// MARK: - Coloured icon tiles

/// 26pt rounded gradient tile in `color`, with a hairline white edge.
private struct ColorTile: ViewModifier {
    let color: Color
    func body(content: Content) -> some View {
        content
            .frame(width: 26, height: 26)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(
                LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.white.opacity(0.18)))
    }
}
extension View { func colorTile(_ color: Color) -> some View { modifier(ColorTile(color: color)) } }

/// White SF Symbol on a coloured tile.
struct IconTile: View {
    let symbol: String
    let color: Color
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .colorTile(color)
    }
}

/// A white template-rendered asset (a brand logo) on a coloured tile.
struct AssetIconTile: View {
    let asset: String
    let color: Color
    var glyph: CGFloat = 15
    var body: some View {
        Image(asset).renderingMode(.template).resizable().scaledToFit()
            .frame(width: glyph, height: glyph)
            .foregroundStyle(.white)
            .colorTile(color)
    }
}

/// The same tile at hero size, for a window with one thing to say — a first-run
/// walkthrough, an empty state.
struct HeroTile: View {
    let symbol: String
    let color: Color
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 32, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 68, height: 68)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(
                LinearGradient(colors: [color, color.opacity(0.72)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.18)))
            .shadow(color: color.opacity(0.28), radius: 12, y: 5)
    }
}

/// Leading "icon tile + text" label, used by almost every settings row.
func iconLabel(_ symbol: String, _ color: Color, _ text: String) -> some View {
    HStack(spacing: 10) { IconTile(symbol: symbol, color: color); Text(text) }
}

/// A feature row's leading label: icon tile + title over a wrapping secondary
/// subtitle. The subtitle is where a setting earns its keep — say what turning
/// it on actually does, not a restatement of the title.
func featureLabel(_ symbol: String, _ color: Color, _ title: String, _ subtitle: String) -> some View {
    HStack(spacing: 10) {
        IconTile(symbol: symbol, color: color)
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A feature row with icon + title + subtitle on the left and a trailing
/// control (picker, stepper, …) on the right.
@ViewBuilder
func optionRow<Control: View>(
    symbol: String, color: Color, title: String, subtitle: String,
    @ViewBuilder control: () -> Control
) -> some View {
    HStack(spacing: 12) {
        featureLabel(symbol, color, title, subtitle)
        Spacer(minLength: 8)
        control()
    }
    .padding(.vertical, 2)
}

/// A green "good news" capsule — for a row that reports a state rather than
/// offering an action (a permission that is already granted).
struct GrantedPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.green)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(Color.green.opacity(0.15)))
    }
}

// MARK: - Sidebar row icon

/// A System-Settings-style sidebar icon: white SF Symbol on a coloured rounded
/// square. Rasterized so the row-selection vibrancy cannot tint it.
struct SidebarIcon: View {
    let symbol: String
    let color: Color
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(RoundedRectangle(cornerRadius: 6).fill(
                LinearGradient(colors: [color.opacity(0.98), color.opacity(0.68)],
                               startPoint: .top, endPoint: .bottom)))
            .drawingGroup()
    }
}

// MARK: - Status dot

/// Solid green when the app can actually do its job, orange when it cannot.
struct StatusDot: View {
    let active: Bool
    var body: some View {
        Circle()
            .fill(active ? Color.green : Color.orange)
            .frame(width: 9, height: 9)
            .frame(width: 12, height: 12)
    }
}

// MARK: - Root view

struct SettingsRootView: View {
    @EnvironmentObject var store: SettingsStore

    // ─────────────────────────────────────────────────────────────────
    // UNCOMMENT this line together with `.id(languageRevision.value)` at the
    // bottom of `body`, ONLY if the in-app interface-language picker was
    // selected (needs LocalizationOverride.swift).
    //
    // The `@ObservedObject` is not optional decoration — it is the whole
    // mechanism. Writing `.id(LanguageRevision.shared.value)` on its own reads
    // the counter without SUBSCRIBING to it, so SwiftUI never learns it
    // changed and the window keeps rendering the old language until something
    // unrelated forces a redraw.
    // ─────────────────────────────────────────────────────────────────
    //
    // @ObservedObject private var languageRevision = LanguageRevision.shared

    var body: some View {
        NavigationSplitView {
            List(selection: $store.page) {
                ForEach(SettingsPage.allCases, id: \.self) { page in
                    sidebarRow(page)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 208, max: 240)
            .safeAreaInset(edge: .top, spacing: 0) { brand }
            .safeAreaInset(edge: .bottom, spacing: 0) { statusFooter }
        } detail: {
            Group {
                switch store.page {
                case .general: GeneralPage()
                case .about:   AboutPage()
                }
            }
            .accessibilityIdentifier("page.\(store.page.axID)")
            .environment(\.defaultMinListRowHeight, 34)
            .scrollContentBackground(.hidden)
            .auroraBackground()
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: toggleSidebar) { Image(systemName: "sidebar.leading") }
                        .help("Toggle sidebar")
                }
            }
        }
        .frame(minWidth: 700, minHeight: 520)
        // UNCOMMENT with the @ObservedObject above (interface-language picker
        // only). `store.page` lives in the store, not in @State, so the selected
        // page survives the rebuild.
        //
        // .id(languageRevision.value)
    }

    private func sidebarRow(_ page: SettingsPage) -> some View {
        HStack(spacing: 9) {
            SidebarIcon(symbol: page.symbol, color: page.color)
            Text(page.title)
        }
        .padding(.vertical, 2)
        .tag(page)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("nav.\(page.axID)")
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "{{AppName}}").font(.system(size: 14, weight: .bold))
                Text(verbatim: "v\(AppInfo.shortVersion)")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)
    }

    /// One honest line about whether the app can currently do its job.
    ///
    /// Make this report the thing that actually blocks the app — a missing
    /// permission, a helper that will not install — not a decorative "running"
    /// light that is green no matter what. A status light that is always green
    /// is worse than no status light.
    private var statusFooter: some View {
        HStack(spacing: 7) {
            StatusDot(active: store.isOperational)
            Text(store.statusText)
                .font(.system(size: 11)).foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
    }

    /// Toggle the split view's sidebar by sending AppKit's `toggleSidebar:` up
    /// the responder chain — the SwiftUI split view is backed by an
    /// `NSSplitViewController`, which handles it.
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

// MARK: - Bundle info

/// The two Info.plist fields the UI shows, in one place so the About page and
/// the sidebar brand can never disagree about which one they read.
enum AppInfo {
    static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }
}
