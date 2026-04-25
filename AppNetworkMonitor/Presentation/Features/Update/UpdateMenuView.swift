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
                if updateChecker.updateInfo?.downloadUrl != nil {
                    Button("Install Update") {
                        Task {
                            await updateChecker.downloadAndInstallUpdate()
                        }
                    }
                }
                Button("Open Release Page") {
                    updateChecker.openReleasePage()
                }
                Button("Later", role: .cancel) {}
            } message: {
                if let info = updateChecker.updateInfo {
                    Text("A new version (\(info.latestVersion)) is available.\nYou are currently running version \(info.currentVersion).")
                }
            }
            .alert("No Updates Available", isPresented: $updateChecker.showNoUpdateAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                if let info = updateChecker.updateInfo {
                    Text("You're running the latest version (\(info.currentVersion)).")
                } else {
                    Text("You're already up to date.")
                }
            }
            .alert("Update Error", isPresented: .init(
                get: { updateChecker.errorMessage != nil },
                set: { if !$0 { updateChecker.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = updateChecker.errorMessage {
                    Text(error)
                }
            }
            .overlay {
                if updateChecker.isDownloading || updateChecker.isInstalling {
                    UpdateProgressOverlay(updateChecker: updateChecker)
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
            } else if updateChecker.isDownloading || updateChecker.isInstalling {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
                Text(updateChecker.isInstalling ? "Installing..." : "Downloading...")
                    .font(.caption)
            } else if let info = updateChecker.updateInfo, info.isUpdateAvailable {
                Button(action: {
                    if info.downloadUrl != nil {
                        Task { await updateChecker.downloadAndInstallUpdate() }
                    } else {
                        updateChecker.openReleasePage()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                        Text("Update")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .help("Version \(info.latestVersion) available — click to install")
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

// MARK: - Progress Overlay

struct UpdateProgressOverlay: View {
    @ObservedObject var updateChecker: UpdateChecker
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                if updateChecker.isInstalling {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Installing update...")
                        .font(.headline)
                    Text("The app will restart automatically")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ProgressView(value: updateChecker.downloadProgress) {
                        Text("Downloading update...")
                            .font(.headline)
                    }
                    .progressViewStyle(.linear)
                    Text("\(Int(updateChecker.downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(32)
            .frame(width: 300)
            .background(.regularMaterial)
            .cornerRadius(12)
        }
    }
}
