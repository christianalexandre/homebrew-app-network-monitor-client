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
               let log = viewModel.log(forId: selectedId) {
                LogDetailView(log: log, onMock: { viewModel.addMockRule($0) })
            } else {
                Text("Select a request to inspect")
                    .foregroundColor(.secondary)
            }
        }
        .task { viewModel.startIfNeeded() }
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
                viewModel: viewModel,
                onDismiss: { showFilterSheet = false }
            )
        }
    }
}

struct FilterSheetContent: View {
    @ObservedObject var viewModel: DashboardViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Filters").font(.title2).fontWeight(.semibold)
                Spacer()
                Button("Done", action: onDismiss)
                    .buttonStyle(.borderedProminent)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusCodeSection
                    Divider()
                    hostSection
                }
            }
        }
        .padding()
        .frame(width: 380, height: 500)
    }

    private var statusCodeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Status Code").font(.headline)
                Spacer()

                Button("All") { viewModel.showAllStatusCategories() }
                    .font(.caption)
                    .buttonStyle(.link)

                Text("|").foregroundColor(.secondary)

                Button("None") { viewModel.hideAllStatusCategories() }
                    .font(.caption)
                    .buttonStyle(.link)
            }

            HStack(spacing: 8) {
                ForEach(StatusCodeCategory.allCases) { category in
                    StatusCategoryToggle(
                        category: category,
                        isEnabled: !viewModel.disabledStatusCategories.contains(category),
                        onToggle: { viewModel.toggleStatusCategory(category) }
                    )
                }
            }
        }
    }

    private var hostSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Host").font(.headline)
                Spacer()

                if !viewModel.availableHosts.isEmpty {
                    Button("All") { viewModel.showAllHosts() }
                        .font(.caption)
                        .buttonStyle(.link)

                    Text("|").foregroundColor(.secondary)

                    Button("None") { viewModel.hideAllHosts() }
                        .font(.caption)
                        .buttonStyle(.link)
                }
            }

            if viewModel.availableHosts.isEmpty {
                Text("No requests yet")
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.availableHosts, id: \.self) { host in
                        Toggle(isOn: Binding(
                            get: { !viewModel.disabledHosts.contains(host) },
                            set: { _ in viewModel.toggleHostVisibility(host) }
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
