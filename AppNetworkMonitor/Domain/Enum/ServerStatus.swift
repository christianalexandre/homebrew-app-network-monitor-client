import Foundation

enum ServerStatus: Equatable {
    case stopped
    case starting
    case listening(port: UInt16)
    case failed(error: String)
    
    var label: String {
        switch self {
        case .stopped: return "Stopped"
        case .starting: return "Starting..."
        case .listening(let port): return "Listening on :\(port)"
        case .failed(let error): return "Error: \(error)"
        }
    }
}
