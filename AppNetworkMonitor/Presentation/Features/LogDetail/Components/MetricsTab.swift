import SwiftUI

struct MetricsTab: View {
    let log: LogModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Transaction Metrics").font(.headline).padding(.bottom)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    Text("Total Duration").bold()
                    Text(String(format: "%.4f s", log.duration))
                        .monospacedDigit()
                }
                GridRow {
                    Text("Start Time").bold()
                    Text(log.formattedTime)
                }
                GridRow {
                    Text("Status Code").bold()
                    StatusCodeBadge(code: log.statusCode)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
