import SwiftUI

/// Menu bar item for checking updates
struct UpdateMenuCommands: Commands {
    @ObservedObject var updateChecker: UpdateChecker
    
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates...") {
                Task {
                    await updateChecker.checkForUpdates()
                }
            }
            .keyboardShortcut("U", modifiers: [.command, .shift])
            .disabled(updateChecker.isChecking)
        }
    }
}

/// Alert view for update notification
struct UpdateAlertModifier: ViewModifier {
    @ObservedObject var updateChecker: UpdateChecker
    
    func body(content: Content) -> some View {
        content
            .alert("Update Available", isPresented: $updateChecker.showUpdateAlert) {
                Button("Download") {
                    updateChecker.openReleasePage()
                }
                Button("Later", role: .cancel) {}
            } message: {
                if let info = updateChecker.updateInfo {
                    Text("A new version (\(info.latestVersion)) is available.\nYou are currently running version \(info.currentVersion).")
                }
            }
    }
}

/// View extension for easy update alert attachment
extension View {
    func withUpdateAlert(checker: UpdateChecker) -> some View {
        modifier(UpdateAlertModifier(updateChecker: checker))
    }
}

/// Status bar indicator for updates (optional toolbar item)
struct UpdateStatusView: View {
    @ObservedObject var updateChecker: UpdateChecker
    
    var body: some View {
        HStack(spacing: 4) {
            if updateChecker.isChecking {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
            } else if let info = updateChecker.updateInfo, info.isUpdateAvailable {
                Button(action: { updateChecker.openReleasePage() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                        Text("Update")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .help("Version \(info.latestVersion) available")
            }
        }
    }
}

// MARK: - Preview

#Preview("Update Available") {
    UpdateStatusView(updateChecker: {
        let checker = UpdateChecker()
        return checker
    }())
}
