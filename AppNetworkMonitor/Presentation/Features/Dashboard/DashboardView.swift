//
//  DashboardView.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 19/12/25.
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showFilterSheet = false
    @State private var showMockRulesPopover = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel, showFilterSheet: $showFilterSheet)
        } detail: {
            if let selectedId = viewModel.selectedLogId,
               let log = viewModel.allLogs.first(where: { $0.id == selectedId }) {
                LogDetailView(log: log, onMock: { viewModel.addMockRule($0) })
            } else {
                Text("Select a request to inspect")
                    .foregroundColor(.secondary)
            }
        }
        .searchable(text: $viewModel.searchText, placement: .sidebar, prompt: "Search...")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isMockingEnabled ? Color.orange : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(viewModel.isMockingEnabled ? "Mocking" : "Not mocking")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                
                Button(action: { viewModel.toggleMocking() }) {
                    Image(systemName: viewModel.isMockingEnabled ? "stop.circle.fill" : "play.circle.fill")
                        .foregroundColor(viewModel.isMockingEnabled ? .orange : .gray)
                }
                .help(viewModel.isMockingEnabled ? "Stop mocking" : "Start mocking")
                
                Button(action: { showMockRulesPopover.toggle() }) {
                    Image(systemName: "arrow.triangle.swap")
                }
                .help("Manage mock rules")
                .popover(isPresented: $showMockRulesPopover, arrowEdge: .bottom) {
                    MockRulesView(
                        viewModel: viewModel,
                        onDismiss: { showMockRulesPopover = false }
                    )
                    .frame(width: 450, height: 500)
                }
                
                Divider()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isServerRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.isServerRunning ? "Running" : "Stopped")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                
                Button(action: { viewModel.toggleServer() }) {
                    Image(systemName: viewModel.isServerRunning ? "stop.circle.fill" : "play.circle.fill")
                        .foregroundColor(viewModel.isServerRunning ? .red : .green)
                }
                
                Divider()
                
                Button(action: viewModel.clearLogs) {
                    Image(systemName: "trash")
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.connectedClientsCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.caption2)
                    Text("\(viewModel.connectedClientsCount) device\(viewModel.connectedClientsCount > 1 ? "s" : "") connected")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
                .cornerRadius(6)
                .padding(12)
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheetContent(
                availableHosts: viewModel.availableHosts,
                disabledHosts: viewModel.disabledHosts,
                disabledStatusCategories: viewModel.disabledStatusCategories,
                onToggleHost: viewModel.toggleHostVisibility,
                onShowAllHosts: viewModel.showAllHosts,
                onHideAllHosts: viewModel.hideAllHosts,
                onToggleStatusCategory: viewModel.toggleStatusCategory,
                onShowAllStatusCategories: viewModel.showAllStatusCategories,
                onHideAllStatusCategories: viewModel.hideAllStatusCategories,
                onDismiss: { showFilterSheet = false }
            )
        }
    }
}

struct FilterSheetContent: View {
    let availableHosts: [String]
    let disabledHosts: Set<String>
    let disabledStatusCategories: Set<StatusCodeCategory>
    let onToggleHost: (String) -> Void
    let onShowAllHosts: () -> Void
    let onHideAllHosts: () -> Void
    let onToggleStatusCategory: (StatusCodeCategory) -> Void
    let onShowAllStatusCategories: () -> Void
    let onHideAllStatusCategories: () -> Void
    let onDismiss: () -> Void
    
    @State private var localHosts: [String] = []
    @State private var localDisabledHosts: Set<String> = []
    @State private var localDisabledStatusCategories: Set<StatusCodeCategory> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Filters").font(.title2).fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status Code Section
                    statusCodeSection
                    
                    Divider()
                    
                    // Host Section
                    hostSection
                }
            }
        }
        .padding()
        .frame(width: 380, height: 500)
        .onAppear {
            localHosts = availableHosts
            localDisabledHosts = disabledHosts
            localDisabledStatusCategories = disabledStatusCategories
        }
    }
    
    // MARK: - Status Code Section
    
    private var statusCodeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Status Code").font(.headline)
                Spacer()
                
                Button("All") {
                    localDisabledStatusCategories.removeAll()
                    onShowAllStatusCategories()
                }
                .font(.caption)
                .buttonStyle(.link)
                
                Text("|").foregroundColor(.secondary)
                
                Button("None") {
                    localDisabledStatusCategories = Set(StatusCodeCategory.allCases)
                    onHideAllStatusCategories()
                }
                .font(.caption)
                .buttonStyle(.link)
            }
            
            HStack(spacing: 8) {
                ForEach(StatusCodeCategory.allCases) { category in
                    StatusCategoryToggle(
                        category: category,
                        isEnabled: !localDisabledStatusCategories.contains(category),
                        onToggle: {
                            if localDisabledStatusCategories.contains(category) {
                                localDisabledStatusCategories.remove(category)
                            } else {
                                localDisabledStatusCategories.insert(category)
                            }
                            onToggleStatusCategory(category)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Host Section
    
    private var hostSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Host").font(.headline)
                Spacer()
                
                if !localHosts.isEmpty {
                    Button("All") {
                        localDisabledHosts.removeAll()
                        onShowAllHosts()
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                    
                    Text("|").foregroundColor(.secondary)
                    
                    Button("None") {
                        localDisabledHosts = Set(localHosts)
                        onHideAllHosts()
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
            }
            
            if localHosts.isEmpty {
                Text("No requests yet")
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(localHosts, id: \.self) { host in
                        Toggle(isOn: Binding(
                            get: { !localDisabledHosts.contains(host) },
                            set: { isEnabled in
                                if isEnabled {
                                    localDisabledHosts.remove(host)
                                } else {
                                    localDisabledHosts.insert(host)
                                }
                                onToggleHost(host)
                            }
                        )) {
                            Text(host)
                                .font(.body)
                                .lineLimit(1)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
    }
}

// MARK: - Status Category Toggle Button

struct StatusCategoryToggle: View {
    let category: StatusCodeCategory
    let isEnabled: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 16))
                Text(shortLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .frame(width: 60, height: 50)
            .background(isEnabled ? category.color.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isEnabled ? category.color : .gray)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEnabled ? category.color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var shortLabel: String {
        switch category {
        case .pending: return "Pending"
        case .success: return "2xx"
        case .redirection: return "3xx"
        case .clientError: return "4xx"
        case .serverError: return "5xx"
        }
    }
}
