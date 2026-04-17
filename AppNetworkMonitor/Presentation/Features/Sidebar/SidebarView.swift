import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Binding var showFilterSheet: Bool
    
    var body: some View {
        List(viewModel.filteredLogs, selection: $viewModel.selectedLogId) { log in
            LogRow(log: log)
                .tag(log.id)
        }
        .listStyle(.sidebar)
        .navigationTitle("Requests")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .symbolVariant(hasActiveFilters ? .fill : .none)
                }
                .help("Filters")
            }
        }
    }
    
    private var hasActiveFilters: Bool {
        !viewModel.disabledHosts.isEmpty || !viewModel.disabledStatusCategories.isEmpty
    }
}

struct LogRow: View {
    let log: LogModel
    
    var statusColor: Color {
        if log.statusCode == 0 { return .yellow }
        if log.statusCode >= 200 && log.statusCode < 300 { return .green }
        return .red
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(log.statusCode == 0 ? "..." : "\(log.statusCode)")
                .font(.system(size: 10, weight: .bold))
                .padding(4)
                .frame(width: 40)
                .background(statusColor.opacity(0.2))
                .foregroundColor(statusColor)
                .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(log.method)
                        .font(.caption2)
                        .fontWeight(.bold)
                    Text(log.url)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                HStack {
                    Text(log.formattedTime)
                    if log.duration > 0 {
                        Text("• \(String(format: "%.0f", log.duration * 1000))ms")
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
