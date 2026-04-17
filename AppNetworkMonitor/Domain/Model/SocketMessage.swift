import Foundation

public struct SocketMessage: Codable {
    public let type: SocketMessageType
    public let payload: Data
    
    public init(type: SocketMessageType, payload: Data) {
        self.type = type
        self.payload = payload
    }
}
