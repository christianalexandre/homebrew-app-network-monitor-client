import SwiftUI

enum StatusCodeCategory: String, CaseIterable, Identifiable {
    case pending = "Pending"
    case success = "2xx Success"
    case redirection = "3xx Redirect"
    case clientError = "4xx Client Error"
    case serverError = "5xx Server Error"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .pending: return .yellow
        case .success: return .green
        case .redirection: return .blue
        case .clientError: return .orange
        case .serverError: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .success: return "checkmark.circle"
        case .redirection: return "arrow.triangle.turn.up.right.diamond"
        case .clientError: return "exclamationmark.triangle"
        case .serverError: return "xmark.octagon"
        }
    }
    
    static func category(for statusCode: Int) -> StatusCodeCategory {
        switch statusCode {
        case 0: return .pending
        case 200..<300: return .success
        case 300..<400: return .redirection
        case 400..<500: return .clientError
        case 500..<600: return .serverError
        default: return .clientError
        }
    }
}
