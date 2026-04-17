import Foundation
import Testing
@testable import AppNetworkMonitor

@MainActor
struct DashboardViewModelTests {

    // MARK: - Helpers

    private static let filterDebounce: UInt64 = 250_000_000 // 250 ms (filter debounce is 150)
    private static let persistDebounce: UInt64 = 500_000_000 // 500 ms (persist debounce is 300)

    private func makeUserDefaults() -> UserDefaults {
        let suite = "AppNetworkMonitorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makeViewModel(
        fake: FakeServerService = FakeServerService(),
        userDefaults: UserDefaults? = nil,
        maxLogs: Int = 5_000
    ) -> (DashboardViewModel, FakeServerService, UserDefaults) {
        let defaults = userDefaults ?? makeUserDefaults()
        let vm = DashboardViewModel(
            serverService: fake,
            userDefaults: defaults,
            mockRulesKey: "MockRules",
            maxLogs: maxLogs
        )
        return (vm, fake, defaults)
    }

    private func makeLog(
        id: UUID = UUID(),
        url: String = "https://api.example.com/x",
        method: String = "GET",
        statusCode: Int = 200,
        timestamp: Date = Date(),
        requestBody: String? = nil,
        responseBody: String? = nil
    ) -> LogModel {
        LogModel(
            id: id,
            timestamp: timestamp,
            method: method,
            url: url,
            statusCode: statusCode,
            duration: 0,
            requestHeaders: nil,
            responseHeaders: nil,
            requestBody: requestBody,
            responseBody: responseBody
        )
    }

    // MARK: - Log handling

    @Test func receivingLogAppendsToAllLogs() async throws {
        let (vm, fake, _) = makeViewModel()
        fake.logReceived.send(makeLog())
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.allLogs.count == 1)
    }

    @Test func receivingLogWithExistingIdUpdatesInPlace() async throws {
        let (vm, fake, _) = makeViewModel()
        let id = UUID()
        fake.logReceived.send(makeLog(id: id, statusCode: 0))
        try await Task.sleep(nanoseconds: 50_000_000)
        fake.logReceived.send(makeLog(id: id, statusCode: 201))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.allLogs.count == 1)
        #expect(vm.allLogs.first?.statusCode == 201)
    }

    @Test func logForIdReturnsMatchingEntry() async throws {
        let (vm, fake, _) = makeViewModel()
        let id = UUID()
        fake.logReceived.send(makeLog(id: id, url: "https://x.com/a"))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.log(forId: id)?.url == "https://x.com/a")
        #expect(vm.log(forId: UUID()) == nil)
    }

    @Test func availableHostsTracksUniqueHosts() async throws {
        let (vm, fake, _) = makeViewModel()
        fake.logReceived.send(makeLog(url: "https://a.com/x"))
        fake.logReceived.send(makeLog(url: "https://b.com/x"))
        fake.logReceived.send(makeLog(url: "https://a.com/y"))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.availableHosts == ["a.com", "b.com"])
    }

    // MARK: - Cap / FIFO

    @Test func exceedingMaxLogsTrimsOldest() async throws {
        let (vm, fake, _) = makeViewModel(maxLogs: 5)
        for i in 0..<7 {
            fake.logReceived.send(makeLog(url: "https://x.com/\(i)"))
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.allLogs.count == 5)
        #expect(vm.allLogs.first?.url == "https://x.com/2")
        #expect(vm.allLogs.last?.url == "https://x.com/6")
    }

    @Test func trimmingClearsSelectedLogIdIfDropped() async throws {
        let (vm, fake, _) = makeViewModel(maxLogs: 3)
        let firstId = UUID()
        fake.logReceived.send(makeLog(id: firstId, url: "https://x.com/0"))
        try await Task.sleep(nanoseconds: 30_000_000)
        vm.selectedLogId = firstId
        for i in 1..<5 {
            fake.logReceived.send(makeLog(url: "https://x.com/\(i)"))
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.selectedLogId == nil)
    }

    @Test func trimmingPreservesSelectedLogIdIfStillPresent() async throws {
        let (vm, fake, _) = makeViewModel(maxLogs: 3)
        let keepId = UUID()
        fake.logReceived.send(makeLog(url: "https://x.com/0"))
        fake.logReceived.send(makeLog(url: "https://x.com/1"))
        fake.logReceived.send(makeLog(id: keepId, url: "https://x.com/2"))
        try await Task.sleep(nanoseconds: 30_000_000)
        vm.selectedLogId = keepId
        fake.logReceived.send(makeLog(url: "https://x.com/3"))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.selectedLogId == keepId)
    }

    @Test func trimmingDecrementsHostCounts() async throws {
        let (vm, fake, _) = makeViewModel(maxLogs: 2)
        fake.logReceived.send(makeLog(url: "https://a.com/0"))
        fake.logReceived.send(makeLog(url: "https://b.com/0"))
        fake.logReceived.send(makeLog(url: "https://b.com/1"))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.availableHosts == ["b.com"])
    }

    // MARK: - Filtering

    @Test func filteredLogsSortDescendingByTimestamp() async throws {
        let (vm, fake, _) = makeViewModel()
        let now = Date()
        fake.logReceived.send(makeLog(url: "https://x.com/old", timestamp: now.addingTimeInterval(-10)))
        fake.logReceived.send(makeLog(url: "https://x.com/new", timestamp: now))
        try await Task.sleep(nanoseconds: Self.filterDebounce)
        #expect(vm.filteredLogs.first?.url == "https://x.com/new")
        #expect(vm.filteredLogs.last?.url == "https://x.com/old")
    }

    @Test func filteredLogsExcludesDisabledHost() async throws {
        let (vm, fake, _) = makeViewModel()
        fake.logReceived.send(makeLog(url: "https://a.com/x"))
        fake.logReceived.send(makeLog(url: "https://b.com/x"))
        try await Task.sleep(nanoseconds: 50_000_000)
        vm.disabledHosts = ["a.com"]
        try await Task.sleep(nanoseconds: Self.filterDebounce)
        #expect(vm.filteredLogs.count == 1)
        #expect(vm.filteredLogs.first?.host == "b.com")
    }

    @Test func filteredLogsExcludesDisabledStatusCategory() async throws {
        let (vm, fake, _) = makeViewModel()
        fake.logReceived.send(makeLog(statusCode: 200))
        fake.logReceived.send(makeLog(statusCode: 404))
        try await Task.sleep(nanoseconds: 50_000_000)
        vm.disabledStatusCategories = [.clientError]
        try await Task.sleep(nanoseconds: Self.filterDebounce)
        #expect(vm.filteredLogs.count == 1)
        #expect(vm.filteredLogs.first?.statusCode == 200)
    }

    @Test func filteredLogsBySearchTextMatchesUrl() async throws {
        let (vm, fake, _) = makeViewModel()
        fake.logReceived.send(makeLog(url: "https://x.com/users"))
        fake.logReceived.send(makeLog(url: "https://x.com/posts"))
        try await Task.sleep(nanoseconds: 50_000_000)
        vm.searchText = "users"
        try await Task.sleep(nanoseconds: Self.filterDebounce)
        #expect(vm.filteredLogs.count == 1)
        #expect(vm.filteredLogs.first?.url.contains("users") == true)
    }

    @Test func filteredLogsBySearchTextMatchesMethod() async throws {
        let (vm, fake, _) = makeViewModel()
        fake.logReceived.send(makeLog(method: "GET"))
        fake.logReceived.send(makeLog(method: "POST"))
        try await Task.sleep(nanoseconds: 50_000_000)
        vm.searchText = "post"
        try await Task.sleep(nanoseconds: Self.filterDebounce)
        #expect(vm.filteredLogs.count == 1)
        #expect(vm.filteredLogs.first?.method == "POST")
    }

    @Test func filteredLogsBySearchTextMatchesStatusCode() async throws {
        let (vm, fake, _) = makeViewModel()
        fake.logReceived.send(makeLog(statusCode: 200))
        fake.logReceived.send(makeLog(statusCode: 404))
        try await Task.sleep(nanoseconds: 50_000_000)
        vm.searchText = "404"
        try await Task.sleep(nanoseconds: Self.filterDebounce)
        #expect(vm.filteredLogs.count == 1)
        #expect(vm.filteredLogs.first?.statusCode == 404)
    }

    @Test func filteredLogsBySearchTextMatchesRequestBody() async throws {
        let (vm, fake, _) = makeViewModel()
        fake.logReceived.send(makeLog(requestBody: "{\"name\":\"alice\"}"))
        fake.logReceived.send(makeLog(requestBody: "{\"name\":\"bob\"}"))
        try await Task.sleep(nanoseconds: 50_000_000)
        vm.searchText = "alice"
        try await Task.sleep(nanoseconds: Self.filterDebounce)
        #expect(vm.filteredLogs.count == 1)
    }

    @Test func filteredLogsBySearchTextMatchesResponseBody() async throws {
        let (vm, fake, _) = makeViewModel()
        fake.logReceived.send(makeLog(responseBody: "secret-token"))
        fake.logReceived.send(makeLog(responseBody: "other"))
        try await Task.sleep(nanoseconds: 50_000_000)
        vm.searchText = "secret"
        try await Task.sleep(nanoseconds: Self.filterDebounce)
        #expect(vm.filteredLogs.count == 1)
    }

    @Test func emptySearchTextReturnsAll() async throws {
        let (vm, fake, _) = makeViewModel()
        fake.logReceived.send(makeLog(url: "https://x.com/a"))
        fake.logReceived.send(makeLog(url: "https://x.com/b"))
        try await Task.sleep(nanoseconds: 50_000_000)
        vm.searchText = "   "
        try await Task.sleep(nanoseconds: Self.filterDebounce)
        #expect(vm.filteredLogs.count == 2)
    }

    // MARK: - Host filter helpers

    @Test func toggleHostVisibilityFlipsState() {
        let (vm, _, _) = makeViewModel()
        vm.toggleHostVisibility("a.com")
        #expect(vm.disabledHosts == ["a.com"])
        vm.toggleHostVisibility("a.com")
        #expect(vm.disabledHosts.isEmpty)
    }

    @Test func showAllHostsClearsDisabled() {
        let (vm, _, _) = makeViewModel()
        vm.disabledHosts = ["a.com", "b.com"]
        vm.showAllHosts()
        #expect(vm.disabledHosts.isEmpty)
    }

    @Test func hideAllHostsDisablesEveryAvailable() async throws {
        let (vm, fake, _) = makeViewModel()
        fake.logReceived.send(makeLog(url: "https://a.com/x"))
        fake.logReceived.send(makeLog(url: "https://b.com/x"))
        try await Task.sleep(nanoseconds: 50_000_000)
        vm.hideAllHosts()
        #expect(vm.disabledHosts == ["a.com", "b.com"])
    }

    // MARK: - Status category filter helpers

    @Test func toggleStatusCategoryFlipsState() {
        let (vm, _, _) = makeViewModel()
        vm.toggleStatusCategory(.success)
        #expect(vm.disabledStatusCategories == [.success])
        vm.toggleStatusCategory(.success)
        #expect(vm.disabledStatusCategories.isEmpty)
    }

    @Test func showAllStatusCategoriesClearsDisabled() {
        let (vm, _, _) = makeViewModel()
        vm.disabledStatusCategories = [.success, .clientError]
        vm.showAllStatusCategories()
        #expect(vm.disabledStatusCategories.isEmpty)
    }

    @Test func hideAllStatusCategoriesDisablesAllCases() {
        let (vm, _, _) = makeViewModel()
        vm.hideAllStatusCategories()
        #expect(vm.disabledStatusCategories == Set(StatusCodeCategory.allCases))
    }

    // MARK: - Clear logs

    @Test func clearLogsResetsAllState() async throws {
        let (vm, fake, _) = makeViewModel()
        fake.logReceived.send(makeLog(url: "https://a.com/x"))
        try await Task.sleep(nanoseconds: 50_000_000)
        vm.selectedLogId = vm.allLogs.first?.id
        vm.clearLogs()
        #expect(vm.allLogs.isEmpty)
        #expect(vm.availableHosts.isEmpty)
        #expect(vm.selectedLogId == nil)
    }

    // MARK: - Server toggle / start

    @Test func startIfNeededIsIdempotent() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.startIfNeeded()
        vm.startIfNeeded()
        #expect(fake.startCalls == 1)
    }

    @Test func toggleServerStopsWhenRunning() async throws {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.startIfNeeded()
        try await Task.sleep(nanoseconds: 30_000_000)
        vm.toggleServer()
        #expect(fake.stopCalls == 1)
    }

    @Test func toggleServerStartsWhenStopped() async throws {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.startIfNeeded()
        try await Task.sleep(nanoseconds: 30_000_000)
        vm.toggleServer() // stop
        try await Task.sleep(nanoseconds: 30_000_000)
        vm.toggleServer() // start again
        #expect(fake.startCalls == 2)
    }

    // MARK: - Mock rules CRUD

    @Test func addMockRuleAppendsAndSendsWhenMockingEnabled() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.isMockingEnabled = true
        let rule = MockRule(path: "/x")
        vm.addMockRule(rule)
        #expect(vm.mockRules == [rule])
        #expect(fake.sentMockRules == [rule])
    }

    @Test func addMockRuleDoesNotSendWhenMockingDisabled() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.addMockRule(MockRule(path: "/x"))
        #expect(fake.sentMockRules.isEmpty)
    }

    @Test func addDisabledMockRuleNeverSends() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.isMockingEnabled = true
        vm.addMockRule(MockRule(path: "/x", isEnabled: false))
        #expect(fake.sentMockRules.isEmpty)
    }

    @Test func updateMockRuleReplacesAndResendsWhenEnabled() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.isMockingEnabled = true
        let id = UUID()
        let original = MockRule(id: id, path: "/x", statusCode: 200)
        vm.addMockRule(original)
        let updated = MockRule(id: id, path: "/x", statusCode: 500)
        vm.updateMockRule(updated)
        #expect(vm.mockRules == [updated])
        #expect(fake.removedMockRuleIds == [id])
        #expect(fake.sentMockRules == [original, updated])
    }

    @Test func updateMockRuleToDisabledRemovesWithoutResending() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.isMockingEnabled = true
        let id = UUID()
        vm.addMockRule(MockRule(id: id, path: "/x"))
        let disabled = MockRule(id: id, path: "/x", isEnabled: false)
        vm.updateMockRule(disabled)
        #expect(fake.removedMockRuleIds == [id])
        #expect(fake.sentMockRules.count == 1) // only the original add
    }

    @Test func updateUnknownMockRuleIsNoop() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.updateMockRule(MockRule(path: "/missing"))
        #expect(vm.mockRules.isEmpty)
        #expect(fake.removedMockRuleIds.isEmpty)
    }

    @Test func deleteMockRuleRemovesAndSendsRemoveWhenMocking() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.isMockingEnabled = true
        let rule = MockRule(path: "/x")
        vm.addMockRule(rule)
        vm.deleteMockRule(rule)
        #expect(vm.mockRules.isEmpty)
        #expect(fake.removedMockRuleIds == [rule.id])
    }

    @Test func deleteMockRuleSilentWhenMockingDisabled() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        let rule = MockRule(path: "/x")
        vm.addMockRule(rule)
        vm.deleteMockRule(rule)
        #expect(fake.removedMockRuleIds.isEmpty)
    }

    @Test func toggleMockRuleEnablesAndSends() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.isMockingEnabled = true
        let rule = MockRule(path: "/x", isEnabled: false)
        vm.addMockRule(rule)
        vm.toggleMockRule(rule)
        #expect(vm.mockRules.first?.isEnabled == true)
        #expect(fake.sentMockRules.last?.isEnabled == true)
    }

    @Test func toggleMockRuleDisablesAndRemoves() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.isMockingEnabled = true
        let rule = MockRule(path: "/x")
        vm.addMockRule(rule)
        vm.toggleMockRule(rule)
        #expect(vm.mockRules.first?.isEnabled == false)
        #expect(fake.removedMockRuleIds == [rule.id])
    }

    @Test func toggleUnknownMockRuleIsNoop() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.toggleMockRule(MockRule(path: "/missing"))
        #expect(vm.mockRules.isEmpty)
    }

    @Test func clearAllMockRulesEmptiesAndSendsClearWhenMocking() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.isMockingEnabled = true
        vm.addMockRule(MockRule(path: "/x"))
        vm.clearAllMockRules()
        #expect(vm.mockRules.isEmpty)
        #expect(fake.clearAllCalls == 1)
    }

    @Test func clearAllMockRulesSilentWhenMockingDisabled() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.addMockRule(MockRule(path: "/x"))
        vm.clearAllMockRules()
        #expect(fake.clearAllCalls == 0)
    }

    // MARK: - Mocking toggle

    @Test func enableMockingSyncsEnabledRules() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.mockRules = [
            MockRule(path: "/a", isEnabled: true),
            MockRule(path: "/b", isEnabled: false)
        ]
        vm.toggleMocking()
        #expect(vm.isMockingEnabled)
        #expect(fake.syncedRuleSets.last?.count == 1)
        #expect(fake.syncedRuleSets.last?.first?.path == "/a")
    }

    @Test func disableMockingClearsAllOnDevice() {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.isMockingEnabled = true
        vm.toggleMocking()
        #expect(!vm.isMockingEnabled)
        #expect(fake.clearAllCalls == 1)
    }

    // MARK: - Sync on first connection

    @Test func mockRulesSyncedWhenFirstClientConnects() async throws {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.isMockingEnabled = true
        vm.addMockRule(MockRule(path: "/x"))
        let syncCountBefore = fake.syncedRuleSets.count

        fake.connectedClientsCount = 1
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(fake.syncedRuleSets.count == syncCountBefore + 1)
    }

    @Test func mockRulesNotSyncedOnSubsequentConnects() async throws {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.isMockingEnabled = true
        fake.connectedClientsCount = 1
        try await Task.sleep(nanoseconds: 30_000_000)
        let syncCount = fake.syncedRuleSets.count
        fake.connectedClientsCount = 2
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(fake.syncedRuleSets.count == syncCount)
    }

    @Test func mockRulesNotSyncedWhenMockingDisabled() async throws {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        vm.addMockRule(MockRule(path: "/x"))
        fake.connectedClientsCount = 1
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(fake.syncedRuleSets.isEmpty)
        _ = vm
    }

    // MARK: - Persistence

    @Test func persistsMockRulesAfterDebounce() async throws {
        let defaults = makeUserDefaults()
        let (vm, _, _) = makeViewModel(userDefaults: defaults)
        vm.addMockRule(MockRule(path: "/persisted"))
        try await Task.sleep(nanoseconds: Self.persistDebounce)

        let data = defaults.data(forKey: "MockRules")
        #expect(data != nil)
        let decoded = try JSONDecoder().decode([MockRule].self, from: data!)
        #expect(decoded.first?.path == "/persisted")
    }

    @Test func loadsMockRulesFromUserDefaultsOnInit() throws {
        let defaults = makeUserDefaults()
        let rules = [MockRule(path: "/loaded")]
        let data = try JSONEncoder().encode(rules)
        defaults.set(data, forKey: "MockRules")

        let vm = DashboardViewModel(
            serverService: FakeServerService(),
            userDefaults: defaults,
            mockRulesKey: "MockRules"
        )
        #expect(vm.mockRules == rules)
    }

    @Test func ignoresCorruptPersistedData() {
        let defaults = makeUserDefaults()
        defaults.set(Data("not json".utf8), forKey: "MockRules")

        let vm = DashboardViewModel(
            serverService: FakeServerService(),
            userDefaults: defaults,
            mockRulesKey: "MockRules"
        )
        #expect(vm.mockRules.isEmpty)
    }

    // MARK: - Server status mirroring

    @Test func isServerRunningMirrorsService() async throws {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        fake.isRunning = true
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(vm.isServerRunning)
        fake.isRunning = false
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(!vm.isServerRunning)
    }

    @Test func connectedClientsCountMirrorsService() async throws {
        let fake = FakeServerService()
        let (vm, _, _) = makeViewModel(fake: fake)
        fake.connectedClientsCount = 3
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(vm.connectedClientsCount == 3)
    }
}
