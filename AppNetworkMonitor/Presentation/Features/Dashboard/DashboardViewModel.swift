//
//  DashboardViewModel.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 17/12/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var allLogs: [LogModel] = []
    @Published var searchText: String = ""
    @Published var selectedLogId: UUID?
    @Published var isServerRunning: Bool = false
    @Published var connectedClientsCount: Int = 0
    @Published var disabledHosts: Set<String> = []
    @Published var disabledStatusCategories: Set<StatusCodeCategory> = []
    
    @Published var mockRules: [MockRule] = [] {
        didSet { saveMockRules() }
    }
    @Published var isMockingEnabled: Bool = false
    
    private let mockRulesKey = "AppNetworkMonitor.MockRules"
    
    let serverService: ServerServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    var availableHosts: [String] {
        let hosts = allLogs.map { $0.host }
        return Array(Set(hosts)).sorted()
    }
    
    var filteredLogs: [LogModel] {
        let sortedLogs = allLogs.sorted { $0.timestamp > $1.timestamp }
        
        return sortedLogs.filter { log in
            if disabledHosts.contains(log.host) {
                return false
            }
            
            let category = StatusCodeCategory.category(for: log.statusCode)
            if disabledStatusCategories.contains(category) {
                return false
            }
            
            guard !searchText.isEmpty else { return true }
            
            if log.url.localizedCaseInsensitiveContains(searchText) ||
                log.method.localizedCaseInsensitiveContains(searchText) ||
                String(log.statusCode).contains(searchText) {
                return true
            }
            
            if let requestBody = log.requestBody,
               requestBody.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            if let responseBody = log.responseBody,
               responseBody.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            
            return false
        }
    }
    
    init() {
        self.serverService = ServerServiceProtocol()
        loadMockRules()
        setupBindings()
        self.toggleServer()
    }
    
    // MARK: - Mock Rules Persistence
    
    private func loadMockRules() {
        guard let data = UserDefaults.standard.data(forKey: mockRulesKey),
              let rules = try? JSONDecoder().decode([MockRule].self, from: data) else {
            return
        }
        mockRules = rules
    }
    
    private func saveMockRules() {
        guard let data = try? JSONEncoder().encode(mockRules) else { return }
        UserDefaults.standard.set(data, forKey: mockRulesKey)
    }
    
    private func setupBindings() {
        serverService.logReceived
            .receive(on: RunLoop.main)
            .sink { [weak self] newLog in
                self?.handleLogSafe(newLog)
            }
            .store(in: &cancellables)
        
        serverService.$isRunning
            .receive(on: RunLoop.main)
            .assign(to: &$isServerRunning)
        
        serverService.$connectedClientsCount
            .receive(on: RunLoop.main)
            .sink { [weak self] newCount in
                guard let self = self else { return }
                
                let previousCount = self.connectedClientsCount
                self.connectedClientsCount = newCount
                
                if self.isMockingEnabled,
                   previousCount == 0,
                   newCount > 0 {
                    self.syncMockRules(self.mockRules.filter { $0.isEnabled })
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleLogSafe(_ log: LogModel) {
        if let index = allLogs.firstIndex(where: { $0.id == log.id }) {
            allLogs[index] = log
        } else {
            allLogs.append(log)
        }
    }
    
    func toggleServer() { isServerRunning ? serverService.stop() : serverService.start() }
    func clearLogs() { allLogs.removeAll(); selectedLogId = nil }
    
    func toggleHostVisibility(_ host: String) {
        if disabledHosts.contains(host) {
            disabledHosts.remove(host)
        } else {
            disabledHosts.insert(host)
        }
    }
    
    func showAllHosts() {
        disabledHosts.removeAll()
    }

    func hideAllHosts() {
        disabledHosts = Set(allLogs.map { $0.host })
    }
    
    // MARK: - Status Code Filters
    
    func toggleStatusCategory(_ category: StatusCodeCategory) {
        if disabledStatusCategories.contains(category) {
            disabledStatusCategories.remove(category)
        } else {
            disabledStatusCategories.insert(category)
        }
    }
    
    func showAllStatusCategories() {
        disabledStatusCategories.removeAll()
    }
    
    func hideAllStatusCategories() {
        disabledStatusCategories = Set(StatusCodeCategory.allCases)
    }
    
    // MARK: - Mock Rules Management
    
    func toggleMocking() {
        isMockingEnabled.toggle()
        if isMockingEnabled {
            let enabledRules = mockRules.filter { $0.isEnabled }
            serverService.syncMockRules(enabledRules)
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
}
