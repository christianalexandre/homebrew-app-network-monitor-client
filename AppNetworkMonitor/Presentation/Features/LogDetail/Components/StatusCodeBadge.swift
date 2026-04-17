import SwiftUI

struct StatusCodeBadge: View {
    let code: Int
    var color: Color {
        if code >= 200 && code < 300 { return .green }
        if code >= 400 && code < 500 { return .orange }
        if code >= 500 { return .red }
        return .gray
    }
    
    var body: some View {
        Text("\(code)")
            .font(.caption).bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}
