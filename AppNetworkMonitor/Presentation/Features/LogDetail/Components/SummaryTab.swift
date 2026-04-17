import SwiftUI

struct SummaryTab: View {
    let log: LogModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionBox(title: "General") {
                DetailRow(label: "Host", value: log.host)
                DetailRow(label: "Path", value: log.path)
                if let query = log.query {
                    DetailRow(label: "Query", value: query)
                }
                DetailRow(label: "Method", value: log.method)
                DetailRow(label: "Status", value: "\(log.statusCode)")
            }
            
            SectionBox(title: "Timing") {
                DetailRow(label: "Timestamp", value: log.formattedTime)
                DetailRow(label: "Duration", value: String(format: "%.3fs", log.duration))
            }
            
            SectionBox(title: "Sizes") {
                let reqSize = log.requestBody?.count ?? 0
                let resSize = log.responseBody?.count ?? 0
                DetailRow(label: "Request Body", value: ByteCountFormatter.string(fromByteCount: Int64(reqSize), countStyle: .file))
                DetailRow(label: "Response Body", value: ByteCountFormatter.string(fromByteCount: Int64(resSize), countStyle: .file))
            }
        }
    }
}

struct SectionBox<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .bold()
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}
