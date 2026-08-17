import AppKit
import SwiftUI

/// App hero, links, updates, copyright.
struct AboutPage: View {
    @EnvironmentObject var store: SettingsStore
    @State private var updateSpin = 0

    // Replace with the app's real links; delete the rows you don't have.
    private static let websiteURL = "https://example.com"
    private static let supportURL = "https://example.com/support"

    private var versionString: String {
        "Version \(AppInfo.shortVersion) (\(AppInfo.build))"
    }

    /// Read from Info.plist rather than duplicated here, so the year and the
    /// licence can never disagree between this page and the bundle.
    private var copyright: String {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? ""
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable().frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    Text(verbatim: "{{AppName}}").font(.title2).fontWeight(.bold)
                    Text(versionString).font(.callout).foregroundStyle(.secondary)
                    Text("One sentence on what {{AppName}} is for.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section {
                linkRow(systemImage: "globe", tint: .blue, title: "Website", url: Self.websiteURL)
                linkRow(systemImage: "lifepreserver.fill", tint: .orange, title: "Support", url: Self.supportURL)
            }

            // If Sparkle or another updater is wired up:
            //
            // Section {
            //     Toggle(isOn: Binding(get: { store.automaticallyChecksForUpdates },
            //                          set: { store.automaticallyChecksForUpdates = $0 })) {
            //         iconLabel("arrow.triangle.2.circlepath", .green, "Check for updates automatically")
            //     }
            // } header: {
            //     Text("Updates")
            // }

            Section {
                Text(verbatim: copyright)
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("About")
        // A manual update check belongs in the page toolbar, not as another row
        // competing with the links.
        //
        // .toolbar {
        //     ToolbarItem {
        //         Button {
        //             updateSpin += 1
        //             store.checkForUpdates()
        //         } label: {
        //             Label("Check for Updates…", systemImage: "arrow.triangle.2.circlepath")
        //                 .symbolEffect(.rotate, value: updateSpin)
        //         }
        //     }
        // }
    }

    private func linkRow(asset: String? = nil, systemImage: String? = nil,
                         tint: Color, title: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            HStack(spacing: 10) {
                if let asset { AssetIconTile(asset: asset, color: tint) }
                else if let systemImage { IconTile(symbol: systemImage, color: tint) }
                Text(verbatim: title)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
            }
            // Without this the row only responds where the glyph and the text
            // are — the gaps between them stay dead, and the row feels broken.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
