import SwiftUI

@main
struct AppNetworkMonitorApp: App {
    @StateObject private var updateChecker = UpdateChecker()
    
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .withUpdateAlert(checker: updateChecker)
                .task {
                    await updateChecker.checkOnLaunchIfNeeded()
                }
        }
        .commands {
            UpdateMenuCommands(updateChecker: updateChecker)
        }
    }
}
