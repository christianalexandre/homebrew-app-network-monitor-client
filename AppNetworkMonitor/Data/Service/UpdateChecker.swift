import Foundation
import AppKit

// MARK: - GitHub Release Model

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let htmlUrl: String
    let publishedAt: String
    let body: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case body
    }
}

// MARK: - Update Info

struct UpdateInfo {
    let currentVersion: String
    let latestVersion: String
    let releaseUrl: String
    let releaseNotes: String
    let isUpdateAvailable: Bool
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
    
    // MARK: - Public Methods
    
    /// Check for updates manually
    func checkForUpdates() async {
        isChecking = true
        errorMessage = nil
        
        do {
            let release = try await fetchLatestRelease()
            let currentVersion = getCurrentVersion()
            let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
            
            let isUpdateAvailable = Self.compareVersions(current: currentVersion, latest: latestVersion)
            
            updateInfo = UpdateInfo(
                currentVersion: currentVersion,
                latestVersion: latestVersion,
                releaseUrl: release.htmlUrl,
                releaseNotes: release.body,
                isUpdateAvailable: isUpdateAvailable
            )
            
            if isUpdateAvailable {
                showUpdateAlert = true
            }
            
            UserDefaults.standard.set(Date(), forKey: lastCheckDateKey)
            
        } catch {
            errorMessage = "Failed to check for updates: \(error.localizedDescription)"
        }
        
        isChecking = false
    }
    
    /// Check for updates on app launch (respects launch count)
    func checkOnLaunchIfNeeded() async {
        let launchCount = UserDefaults.standard.integer(forKey: launchCountKey) + 1
        UserDefaults.standard.set(launchCount, forKey: launchCountKey)
        
        // Check every N launches
        if launchCount % checkEveryNLaunches == 0 {
            await checkForUpdates()
        }
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
    
    // MARK: - Private Methods
    
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
    
    var errorDescription: String? {
        switch self {
        case .noReleases:
            return "No releases found for this repository"
        case .serverError(let code):
            return "Server returned error code: \(code)"
        }
    }
}
