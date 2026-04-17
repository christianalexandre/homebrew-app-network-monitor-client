import Foundation
import Combine
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    static let defaultMaxLogs = 5_000

    let maxLogs: Int

    @Published private(set) var allLogs: [LogModel] = []
    @Published private(set) var availableHosts: [String] = []
    @Published private(set) var filteredLogs: [LogModel] = []

    @Published var searchText: String = ""
    @Published var selectedLogId: UUID?
    @Published var isServerRunning: Bool = false
    @Published var connectedClientsCount: Int = 0
    @Published var disabledHosts: Set<String> = []
    @Published var disabledStatusCategories: Set<StatusCodeCategory> = []

    @Published var mockRules: [MockRule] = []
    @Published var isMockingEnabled: Bool = false

    private let mockRulesKey: String
    private let userDefaults: UserDefaults

    private let serverService: any ServerServicing
    private var cancellables = Set<AnyCancellable>()
    private var hasStarted = false

    private var logIndex: [UUID: Int] = [:]
    private var hostCounts: [String: Int] = [:]

    init(
        serverService: (any ServerServicing)? = nil,
        userDefaults: UserDefaults = .standard,
        mockRulesKey: String = "AppNetworkMonitor.MockRules",
        maxLogs: Int = DashboardViewModel.defaultMaxLogs
    ) {
        self.serverService = serverService ?? ServerService()
        self.userDefaults = userDefaults
        self.mockRulesKey = mockRulesKey
        self.maxLogs = maxLogs
        loadMockRules()
        setupBindings()
    }

    /// Called from the view's `.task` so the server isn't started during VM construction.
    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        serverService.start()
    }

    func log(forId id: UUID) -> LogModel? {
        guard let index = logIndex[id] else { return nil }
        return allLogs[index]
    }

    // MARK: - Bindings

    private func setupBindings() {
        serverService.logReceived
            .receive(on: RunLoop.main)
            .sink { [weak self] newLog in
                self?.handleLog(newLog)
            }
            .store(in: &cancellables)

        serverService.isRunningPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$isServerRunning)

        serverService.connectedClientsCountPublisher
            .receive(on: RunLoop.main)
            .scan((0, 0)) { acc, new in (acc.1, new) }
            .sink { [weak self] previous, current in
                guard let self else { return }
                self.connectedClientsCount = current
                if self.isMockingEnabled, previous == 0, current > 0 {
                    self.serverService.syncMockRules(self.mockRules.filter { $0.isEnabled })
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest4(
            $allLogs,
            $searchText.debounce(for: .milliseconds(150), scheduler: RunLoop.main),
            $disabledHosts,
            $disabledStatusCategories
        )
        .map { logs, search, disabledHosts, disabledCategories in
            Self.computeFilteredLogs(
                logs: logs,
                search: search,
                disabledHosts: disabledHosts,
                disabledCategories: disabledCategories
            )
        }
        .receive(on: RunLoop.main)
        .assign(to: &$filteredLogs)

        $mockRules
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.global(qos: .utility))
            .sink { [userDefaults, mockRulesKey] rules in
                Self.persistMockRules(rules, userDefaults: userDefaults, key: mockRulesKey)
            }
            .store(in: &cancellables)
    }

    private static func computeFilteredLogs(
        logs: [LogModel],
        search: String,
        disabledHosts: Set<String>,
        disabledCategories: Set<StatusCodeCategory>
    ) -> [LogModel] {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)

        return logs
            .lazy
            .filter { log in
                if disabledHosts.contains(log.host) { return false }
                if disabledCategories.contains(StatusCodeCategory.category(for: log.statusCode)) { return false }
                guard !trimmed.isEmpty else { return true }
                if log.url.localizedCaseInsensitiveContains(trimmed) ||
                    log.method.localizedCaseInsensitiveContains(trimmed) ||
                    String(log.statusCode).contains(trimmed) {
                    return true
                }
                if let body = log.requestBody, body.localizedCaseInsensitiveContains(trimmed) { return true }
                if let body = log.responseBody, body.localizedCaseInsensitiveContains(trimmed) { return true }
                return false
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Log management

    private func handleLog(_ log: LogModel) {
        if let index = logIndex[log.id] {
            allLogs[index] = log
        } else {
            logIndex[log.id] = allLogs.count
            allLogs.append(log)
            hostCounts[log.host, default: 0] += 1
            if hostCounts[log.host] == 1 {
                availableHosts = hostCounts.keys.sorted()
            }
            trimLogsIfNeeded()
        }
    }

    private func trimLogsIfNeeded() {
        guard allLogs.count > maxLogs else { return }
        let overflow = allLogs.count - maxLogs
        let dropped = allLogs.prefix(overflow)
        for log in dropped {
            if let count = hostCounts[log.host] {
                if count <= 1 {
                    hostCounts.removeValue(forKey: log.host)
                } else {
                    hostCounts[log.host] = count - 1
                }
            }
            if selectedLogId == log.id { selectedLogId = nil }
        }
        allLogs.removeFirst(overflow)
        rebuildIndex()
        availableHosts = hostCounts.keys.sorted()
    }

    private func rebuildIndex() {
        logIndex.removeAll(keepingCapacity: true)
        for (i, log) in allLogs.enumerated() {
            logIndex[log.id] = i
        }
    }

    func clearLogs() {
        allLogs.removeAll()
        logIndex.removeAll()
        hostCounts.removeAll()
        availableHosts = []
        selectedLogId = nil
    }

    // MARK: - Server toggle

    func toggleServer() {
        if isServerRunning {
            serverService.stop()
        } else {
            serverService.start()
        }
    }

    // MARK: - Host filters

    func toggleHostVisibility(_ host: String) {
        if disabledHosts.contains(host) {
            disabledHosts.remove(host)
        } else {
            disabledHosts.insert(host)
        }
    }

    func showAllHosts() { disabledHosts.removeAll() }
    func hideAllHosts() { disabledHosts = Set(availableHosts) }

    // MARK: - Status code filters

    func toggleStatusCategory(_ category: StatusCodeCategory) {
        if disabledStatusCategories.contains(category) {
            disabledStatusCategories.remove(category)
        } else {
            disabledStatusCategories.insert(category)
        }
    }

    func showAllStatusCategories() { disabledStatusCategories.removeAll() }
    func hideAllStatusCategories() { disabledStatusCategories = Set(StatusCodeCategory.allCases) }

    // MARK: - Mock rules

    func toggleMocking() {
        isMockingEnabled.toggle()
        if isMockingEnabled {
            serverService.syncMockRules(mockRules.filter { $0.isEnabled })
        } else {
            serverService.clearAllMockRules()
        }
    }

    func addMockRule(_ rule: MockRule) {
        mockRules.append(rule)
        if isMockingEnabled && rule.isEnabled {
            serverService.sendMockRule(rule)
        }
    }

    func updateMockRule(_ rule: MockRule) {
        guard let index = mockRules.firstIndex(where: { $0.id == rule.id }) else { return }
        mockRules[index] = rule

        if isMockingEnabled {
            serverService.removeMockRule(id: rule.id)
            if rule.isEnabled {
                serverService.sendMockRule(rule)
            }
        }
    }

    func deleteMockRule(_ rule: MockRule) {
        mockRules.removeAll { $0.id == rule.id }
        if isMockingEnabled {
            serverService.removeMockRule(id: rule.id)
        }
    }

    func toggleMockRule(_ rule: MockRule) {
        guard let index = mockRules.firstIndex(where: { $0.id == rule.id }) else { return }

        let updatedRule = MockRule(
            id: rule.id,
            path: rule.path,
            method: rule.method,
            statusCode: rule.statusCode,
            responseHeaders: rule.responseHeaders,
            responseBody: rule.responseBody,
            delayMs: rule.delayMs,
            isEnabled: !rule.isEnabled
        )

        mockRules[index] = updatedRule

        if isMockingEnabled {
            if updatedRule.isEnabled {
                serverService.sendMockRule(updatedRule)
            } else {
                serverService.removeMockRule(id: updatedRule.id)
            }
        }
    }

    func clearAllMockRules() {
        mockRules.removeAll()
        if isMockingEnabled {
            serverService.clearAllMockRules()
        }
    }

    // MARK: - Persistence

    private func loadMockRules() {
        guard let data = userDefaults.data(forKey: mockRulesKey),
              let rules = try? JSONDecoder().decode([MockRule].self, from: data) else {
            return
        }
        mockRules = rules
    }

    private static func persistMockRules(_ rules: [MockRule], userDefaults: UserDefaults, key: String) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        userDefaults.set(data, forKey: key)
    }
}
