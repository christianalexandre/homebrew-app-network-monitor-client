import Foundation
import Combine
@testable import AppNetworkMonitor

@MainActor
final class FakeServerService: ServerServicing {
    let logReceived = PassthroughSubject<LogModel, Never>()

    @Published var isRunning = false
    @Published var connectedClientsCount = 0

    var isRunningPublisher: AnyPublisher<Bool, Never> { $isRunning.eraseToAnyPublisher() }
    var connectedClientsCountPublisher: AnyPublisher<Int, Never> { $connectedClientsCount.eraseToAnyPublisher() }

    private(set) var startCalls = 0
    private(set) var stopCalls = 0
    private(set) var sentMockRules: [MockRule] = []
    private(set) var removedMockRuleIds: [UUID] = []
    private(set) var clearAllCalls = 0
    private(set) var syncedRuleSets: [[MockRule]] = []

    nonisolated init() {}

    func start() {
        startCalls += 1
        isRunning = true
    }

    func stop() {
        stopCalls += 1
        isRunning = false
        connectedClientsCount = 0
    }

    func sendMockRule(_ rule: MockRule) { sentMockRules.append(rule) }
    func removeMockRule(id: UUID) { removedMockRuleIds.append(id) }
    func clearAllMockRules() { clearAllCalls += 1 }
    func syncMockRules(_ rules: [MockRule]) { syncedRuleSets.append(rules) }
}
