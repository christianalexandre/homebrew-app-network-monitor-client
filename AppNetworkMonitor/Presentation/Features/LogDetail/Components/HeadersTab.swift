import SwiftUI

struct HeadersTab: View {
    let reqHeaders: [String: String]?
    let resHeaders: [String: String]?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HeaderSection(title: "Request Headers", headers: reqHeaders)
            Divider()
            HeaderSection(title: "Response Headers", headers: resHeaders)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    struct HeaderSection: View {
        let title: String
        let headers: [String: String]?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    if let h = headers, !h.isEmpty {
                        Text("\(h.count) items").font(.caption).foregroundColor(.secondary)
                    }
                }
                
                if let headers = headers, !headers.isEmpty {
                    ForEach(headers.sorted(by: <), id: \.key) { key, value in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(key)
                                .font(.system(size: 11, design: .monospaced))
                                .bold()
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(value)
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                } else {
                    Text("No headers available").italic().foregroundColor(.secondary)
                }
            }
        }
    }
}
