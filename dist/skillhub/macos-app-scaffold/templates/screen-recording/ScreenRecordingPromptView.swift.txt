import SwiftUI

/// The only flow that survives a cold start: explain the requirement, send
/// the user to System Settings, poll while the toggle is flipped, then
/// surface a "Relaunch Now" button. Inline polling without an explicit
/// relaunch step is the bug that wastes a day of debugging time.
struct ScreenRecordingPromptView: View {
    // The manager is a process-wide singleton (@MainActor on its declaration),
    // so use @ObservedObject — the view does not own its lifetime.
    @ObservedObject private var permission = ScreenRecordingPermission.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Screen Recording Required", systemImage: "rectangle.dashed.badge.record")
                .font(.title2.bold())

            Group {
                switch permission.status {
                case .notGranted:
                    notGrantedView
                case .grantedPendingRelaunch:
                    pendingRelaunchView
                case .granted:
                    grantedView
                }
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear { permission.startPolling() }
        .onDisappear { permission.stopPolling() }
    }

    private var notGrantedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("{{AppName}} needs Screen Recording permission to capture your screen.")
            Text("After you flip the toggle in System Settings, the app must be relaunched for the change to take effect.")
                .foregroundStyle(.secondary)
                .font(.callout)

            HStack {
                Button("Open System Settings") {
                    permission.requestPermission()
                }
                .keyboardShortcut(.defaultAction)
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
    }

    private var pendingRelaunchView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Permission granted", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Screen Recording requires a full app restart before it begins working. Click Relaunch Now to apply the change.")
                .foregroundStyle(.secondary)
                .font(.callout)

            if let error = permission.relaunchError {
                Text("Relaunch failed: \(error.localizedDescription). Try quitting and reopening manually.")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                Button("Relaunch Now") {
                    permission.relaunch()
                }
                .keyboardShortcut(.defaultAction)
                Button("Later") { dismiss() }
            }
        }
    }

    private var grantedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Screen Recording is enabled", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
    }
}
