import Foundation
import AppKit

// MARK: - GitHub Release Model

struct GitHubReleaseAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let contentType: String
    let size: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case contentType = "content_type"
        case size
    }
}

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let htmlUrl: String
    let publishedAt: String
    let body: String
    let assets: [GitHubReleaseAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case body
        case assets
    }
}

// MARK: - Update Info

struct UpdateInfo {
    let currentVersion: String
    let latestVersion: String
    let releaseUrl: String
    let releaseNotes: String
    let isUpdateAvailable: Bool
    let downloadUrl: String?
}

// MARK: - Update Checker

@MainActor
final class UpdateChecker: ObservableObject {
    
    // MARK: - Configuration
    
    /// GitHub repository owner
    private let repoOwner = "christianalexandre"
    
    /// GitHub repository name
    private let repoName = "homebrew-app-network-monitor-client"
    
    /// UserDefaults key for launch count
    private let launchCountKey = "AppLaunchCount"
    
    /// UserDefaults key for last check date
    private let lastCheckDateKey = "LastUpdateCheckDate"
    
    /// Number of launches between automatic checks
    private let checkEveryNLaunches = 5
    
    // MARK: - Published Properties
    
    @Published var updateInfo: UpdateInfo?
    @Published var isChecking = false
    @Published var errorMessage: String?
    @Published var showUpdateAlert = false
    @Published var showNoUpdateAlert = false
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published var isInstalling = false
    
    // MARK: - Public Methods
    
    /// Check for updates manually — shows feedback for all outcomes
    func checkForUpdates() async {
        await performUpdateCheck(silent: false)
    }
    
    /// Check for updates on app launch (respects launch count) — only alerts if update is available
    func checkOnLaunchIfNeeded() async {
        let launchCount = UserDefaults.standard.integer(forKey: launchCountKey) + 1
        UserDefaults.standard.set(launchCount, forKey: launchCountKey)
        
        // Check every N launches
        if launchCount % checkEveryNLaunches == 0 {
            await performUpdateCheck(silent: true)
        }
    }
    
    private func performUpdateCheck(silent: Bool) async {
        isChecking = true
        errorMessage = nil
        
        do {
            let release = try await fetchLatestRelease()
            let currentVersion = getCurrentVersion()
            let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
            
            let isUpdateAvailable = Self.compareVersions(current: currentVersion, latest: latestVersion)
            
            let zipAsset = release.assets.first { $0.name.hasSuffix(".zip") }
            
            updateInfo = UpdateInfo(
                currentVersion: currentVersion,
                latestVersion: latestVersion,
                releaseUrl: release.htmlUrl,
                releaseNotes: release.body,
                isUpdateAvailable: isUpdateAvailable,
                downloadUrl: zipAsset?.browserDownloadUrl
            )
            
            if isUpdateAvailable {
                showUpdateAlert = true
            } else if !silent {
                showNoUpdateAlert = true
            }
            
            UserDefaults.standard.set(Date(), forKey: lastCheckDateKey)
            
        } catch {
            if !silent {
                errorMessage = "Failed to check for updates: \(error.localizedDescription)"
            }
        }
        
        isChecking = false
    }
    
    /// Open the release page in browser
    func openReleasePage() {
        guard let urlString = updateInfo?.releaseUrl,
              let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
    
    /// Open the releases page directly
    func openReleasesPage() {
        guard let url = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases") else { return }
        NSWorkspace.shared.open(url)
    }
    
    /// Download and install the update automatically
    func downloadAndInstallUpdate() async {
        guard let downloadUrlString = updateInfo?.downloadUrl,
              let downloadUrl = URL(string: downloadUrlString) else {
            errorMessage = "No download URL available"
            return
        }
        
        isDownloading = true
        downloadProgress = 0
        errorMessage = nil
        
        do {
            let zipFileUrl = try await downloadZip(from: downloadUrl)
            
            isDownloading = false
            isInstalling = true
            
            let appBundleUrl = try unzipAndFindApp(zipUrl: zipFileUrl)
            try replaceCurrentApp(with: appBundleUrl)
            
            relaunchApp()
        } catch {
            isDownloading = false
            isInstalling = false
            downloadProgress = 0
            errorMessage = "Update failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Private Methods
    
    private func downloadZip(from url: URL) async throws -> URL {
        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UpdateError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        let expectedLength = httpResponse.expectedContentLength
        let tempDir = FileManager.default.temporaryDirectory
        let zipUrl = tempDir.appendingPathComponent("AppNetworkMonitor-update.zip")
        
        // Remove any previous download
        try? FileManager.default.removeItem(at: zipUrl)
        
        var data = Data()
        if expectedLength > 0 {
            data.reserveCapacity(Int(expectedLength))
        }
        
        for try await byte in asyncBytes {
            data.append(byte)
            if expectedLength > 0 {
                let progress = Double(data.count) / Double(expectedLength)
                await MainActor.run { self.downloadProgress = min(progress, 1.0) }
            }
        }
        
        try data.write(to: zipUrl)
        return zipUrl
    }
    
    private nonisolated func unzipAndFindApp(zipUrl: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppNetworkMonitor-extracted-\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-xk", zipUrl.path, tempDir.path]
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw UpdateError.extractionFailed
        }
        
        // Find the .app bundle in the extracted contents
        let contents = try FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        )
        
        guard let appBundle = contents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.appBundleNotFound
        }
        
        return appBundle
    }
    
    private nonisolated func replaceCurrentApp(with newAppUrl: URL) throws {
        guard let currentAppUrl = Bundle.main.bundleURL as URL? else {
            throw UpdateError.cannotLocateCurrentApp
        }
        
        let fm = FileManager.default
        
        // Move current app to trash as backup
        var trashedUrl: NSURL?
        try fm.trashItem(at: currentAppUrl, resultingItemURL: &trashedUrl)
        
        do {
            try fm.copyItem(at: newAppUrl, to: currentAppUrl)
        } catch {
            // Restore from trash if copy fails
            if let trashedUrl = trashedUrl as URL? {
                try? fm.copyItem(at: trashedUrl, to: currentAppUrl)
            }
            throw UpdateError.installFailed(error.localizedDescription)
        }
    }
    
    private func relaunchApp() {
        guard let appPath = Bundle.main.bundleURL.path as String? else { return }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1 && open \"\(appPath)\""]
        try? task.run()
        
        NSApplication.shared.terminate(nil)
    }
    
    private func fetchLatestRelease() async throws -> GitHubRelease {
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 404 {
            throw UpdateError.noReleases
        }
        
        guard httpResponse.statusCode == 200 else {
            throw UpdateError.serverError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(GitHubRelease.self, from: data)
    }
    
    private func getCurrentVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    /// Compare semantic versions
    /// Returns true if latest > current. Strips pre-release / build suffixes (`-beta.1`, `+abc`).
    nonisolated static func compareVersions(current: String, latest: String) -> Bool {
        let currentComponents = Self.numericComponents(of: current)
        let latestComponents = Self.numericComponents(of: latest)
        
        let maxLength = max(currentComponents.count, latestComponents.count)
        
        for i in 0..<maxLength {
            let currentPart = i < currentComponents.count ? currentComponents[i] : 0
            let latestPart = i < latestComponents.count ? latestComponents[i] : 0
            
            if latestPart > currentPart {
                return true
            } else if latestPart < currentPart {
                return false
            }
        }
        
        return false
    }

    nonisolated static func numericComponents(of version: String) -> [Int] {
        let core = version.split(whereSeparator: { $0 == "-" || $0 == "+" }).first.map(String.init) ?? version
        return core.split(separator: ".").compactMap { Int($0) }
    }
}

// MARK: - Errors

enum UpdateError: LocalizedError {
    case noReleases
    case serverError(Int)
    case extractionFailed
    case appBundleNotFound
    case cannotLocateCurrentApp
    case installFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noReleases:
            return "No releases found for this repository"
        case .serverError(let code):
            return "Server returned error code: \(code)"
        case .extractionFailed:
            return "Failed to extract the update archive"
        case .appBundleNotFound:
            return "Could not find the app in the update archive"
        case .cannotLocateCurrentApp:
            return "Could not locate the current app bundle"
        case .installFailed(let reason):
            return "Failed to install update: \(reason)"
        }
    }
}
